#!/bin/bash
# Publica en GitHub la version de botikor.sh que hay en el ultimo commit de
# main: crea la release vX.Y.Z con botikor.sh y botikor.sh.sha256, que es
# lo que descargan "actualizar_botikor" y "downgrade X".
#
# Uso (desde la carpeta del repositorio, en Git Bash):
#   herramientas/publicar_version.sh            # pregunta antes de publicar
#   herramientas/publicar_version.sh --si       # sin preguntar
#   herramientas/publicar_version.sh --notas "Texto de la release"
#
# Antes de publicar comprueba que: no hay cambios sin guardar, main esta
# subido a GitHub, el script pasa bash -n, TOKEN e ID estan vacios, la
# version tiene formato X.Y.Z, no existe ya y es mayor que la ultima
# publicada. Despues descarga lo publicado y comprueba que coincide.

set -euo pipefail

FICHERO="botikor.sh"
confirmar=1
notas=""

while [ $# -gt 0 ]; do
	case "$1" in
		--si) confirmar=0 ;;
		--notas) shift; notas="${1:-}" ;;
		*) echo "Opcion desconocida: $1" >&2; exit 2 ;;
	esac
	shift
done

fallo() { echo "ERROR: $*" >&2; exit 1; }

if command -v gh >/dev/null 2>&1; then
	GH=gh
elif [ -x "/c/Program Files/GitHub CLI/gh.exe" ]; then
	GH="/c/Program Files/GitHub CLI/gh.exe"
else
	fallo "no encuentro GitHub CLI (gh)"
fi

cd "$(git rev-parse --show-toplevel)" || fallo "no estoy dentro del repositorio"

# 1. Estado del repositorio
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fallo "hay que estar en la rama main"
[ -z "$(git status --porcelain)" ] || fallo "hay cambios sin guardar en un commit (git status)"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fallo "main no coincide con GitHub: haz git push (o git pull) primero"

# 2. Se publica exactamente lo que hay en el commit (con saltos de linea LF).
trabajo=$(mktemp -d)
trap 'rm -rf "$trabajo"' EXIT
git show "HEAD:$FICHERO" > "$trabajo/$FICHERO"

bash -n "$trabajo/$FICHERO" || fallo "$FICHERO no pasa bash -n"
! grep -q $'\r' "$trabajo/$FICHERO" || fallo "$FICHERO tiene saltos de linea CRLF"

grep -qE '^TOKEN=""' "$trabajo/$FICHERO" || fallo "TOKEN no esta vacio en $FICHERO: no se puede publicar"
grep -qE '^ID=""' "$trabajo/$FICHERO" || fallo "ID no esta vacio en $FICHERO: no se puede publicar"

version=$(grep -m1 '^VERSION=' "$trabajo/$FICHERO" | sed -E 's/^VERSION="?([0-9]+\.[0-9]+\.[0-9]+)"?.*/\1/')
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fallo "la primera linea VERSION= no tiene formato X.Y.Z"
etiqueta="v$version"

# 3. Que no exista y que sea mayor que la ultima publicada
if "$GH" release view "$etiqueta" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "refs/tags/$etiqueta" >/dev/null 2>&1; then
	fallo "la version $etiqueta ya existe en GitHub: sube VERSION= en $FICHERO"
fi

ultima=$("$GH" release list --exclude-drafts --limit 100 --json tagName --jq '.[].tagName' \
	| sed -n 's/^v\([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)

if [ -n "$ultima" ]; then
	mayor=$(printf '%s\n%s\n' "$ultima" "$version" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
	if [ "$mayor" != "$version" ] || [ "$version" = "$ultima" ]; then
		fallo "la version $version no es mayor que la ultima publicada ($ultima)"
	fi
fi

# 4. Huella
( cd "$trabajo" && sha256sum "$FICHERO" > "$FICHERO.sha256" )
huella=$(cut -d' ' -f1 "$trabajo/$FICHERO.sha256")

[ -n "$notas" ] || notas="BOTikor $version (beta). Para instalarla en el deco basta con enviar /actualizar_botikor al bot."

echo
echo "Se va a publicar:"
echo "  Version:   $etiqueta (ultima publicada: ${ultima:-ninguna})"
echo "  Commit:    $(git log -1 --format='%h %s')"
echo "  SHA-256:   $huella"
echo "  Notas:     $notas"
echo

if [ "$confirmar" = 1 ]; then
	read -r -p "Escribe 'si' para publicar: " respuesta
	[ "$respuesta" = "si" ] || fallo "cancelado, no se ha publicado nada"
fi

"$GH" release create "$etiqueta" "$trabajo/$FICHERO" "$trabajo/$FICHERO.sha256" \
	--target "$(git rev-parse HEAD)" --title "BOTikor $version" --notes "$notas"

# 5. Comprobacion: lo publicado coincide con lo que se queria publicar
mkdir "$trabajo/bajado"
"$GH" release download "$etiqueta" --dir "$trabajo/bajado"
( cd "$trabajo/bajado" && sha256sum -c "$FICHERO.sha256" ) || fallo "lo publicado NO coincide con su huella: revisa la release en GitHub"

git fetch -q --tags origin
echo
echo "Publicada $etiqueta y comprobada."

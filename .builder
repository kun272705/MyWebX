#!/usr/bin/env bash

set -euo pipefail

copy_file() {

  local src="$1"
  local dst="$2"

  if [ -f "$src" ]; then

    mkdir -p "${dst%/*}"

    cp "$src" "$dst"
  fi
}

build_jar() {

  local input="$1"
  local output="$2"

  if [ -f "$input" ]; then

    local indir="${input%/*}/"
    local outdir="${output%/*}/"

    mkdir -p "${outdir}classes/"

    if [[ "${MODE:-production}" == development ]]; then

      javac -cp @classpath.txt "${input/%Handler.java/*.java}" -d "${outdir}classes/" -g
    else

      javac -cp @classpath.txt "${input/%Handler.java/*.java}" -d "${outdir}classes/"
    fi

    local args=("-C" "${outdir}classes/" "./")

    local dir="${input%/*}"
    local name="${dir##*/}"

    if [ -f "${indir}${name}.html" ]; then

      if [[ "${MODE:-production}" == development ]]; then

        npx ejs "${indir}${name}.html" -o "${outdir}template.html"
      else

        npx ejs "${indir}${name}.html" -o "${outdir}template.html" -w
      fi

      args+=("-C" "$outdir" "template.html")
    fi

    if [ -d "${indir}resources/" ]; then

      args+=("-C" "$indir" "resources/")
    fi

    jar cf "$output" "${args[@]}"

    rm -r "${outdir}classes/"
    rm -f "${outdir}template.html"
  fi
}

build_css() {

  local input="$1"
  local output="$2"

  if [ -f "$input" ]; then
    
    if [[ "${MODE:-production}" == development ]]; then

      npx lightningcss "$input" -o "$output" --bundle --browserslist
    else

      npx lightningcss "$input" -o "$output" --bundle --browserslist --minify
    fi
  fi
}

build_js() {

  local input="$1"
  local output="$2"

  if [ -f "$input" ]; then

    npx rollup -i "$input" -o "${output/%.js/.combined.js}" -f iife --failAfterWarnings

    npx swc "${output/%.js/.combined.js}" -o "${output/%.js/.transpiled.js}"

    if [[ "${MODE:-production}" == development ]]; then

      cp "${output/%.js/.transpiled.js}" "$output"
    else

      npx terser "${output/%.js/.transpiled.js}" -o "${output/%.js/.compressed.js}" -c -m

      cp "${output/%.js/.compressed.js}" "$output"
    fi

    rm "${output/%.js/.combined.js}"
    rm "${output/%.js/.transpiled.js}"
    rm -f "${output/%.js/.compressed.js}"
  fi
}

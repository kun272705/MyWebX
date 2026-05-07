#!/usr/bin/env bash

set -euo pipefail

copy_file() {

  local input="$1"
  local output="$2"

  if [ -f "$input" ]; then

    mkdir -p "${output%/*}"

    cp "$input" "$output"
  fi
}

build_jar() {

  local input="$1"
  local output="$2"

  if [ -f "$input" ]; then

    local indir="${input%/*}/"
    local outdir="${output%/*}/"

    mkdir -p "${outdir}classes/"

    if [[ "${MODE:-development}" == production ]]; then

      javac -cp @classpath.txt "${input/%Handler.java/*.java}" -d "${outdir}classes/"
    else

      javac -cp @classpath.txt "${input/%Handler.java/*.java}" -d "${outdir}classes/" -g
    fi

    local args=("-C" "${outdir}classes/" "./")

    if [ -d "${indir}resources/" ]; then

      args+=("-C" "$indir" "resources/")
    fi

    local dir="${input%/*}"
    local name="${dir##*.}"

    if [ -f "${indir}${name}.html" ]; then

      if [[ "${MODE:-development}" == production ]]; then

        npx ejs "${indir}${name}.html" -o "${outdir}template.html" -m ! -w
      else

        npx ejs "${indir}${name}.html" -o "${outdir}template.html" -m !
      fi

      args+=("-C" "$outdir" "template.html")
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
    
    if [[ "${MODE:-development}" == production ]]; then

      npx lightningcss "$input" -o "$output" --bundle --browserslist --minify
    else

      npx lightningcss "$input" -o "$output" --bundle --browserslist
    fi
  fi
}

build_js() {

  local input="$1"
  local output="$2"

  if [ -f "$input" ]; then

    npx rolldown "$input" -o "${output/%.js/.combined.js}" -f iife

    npx swc "${output/%.js/.combined.js}" -o "${output/%.js/.transpiled.js}"

    if [[ "${MODE:-development}" == production ]]; then

      npx rolldown "${output/%.js/.transpiled.js}" -o "$output" -m
    else

      cp "${output/%.js/.transpiled.js}" "$output"
    fi

    rm "${output/%.js/.combined.js}"
    rm "${output/%.js/.transpiled.js}"
  fi
}

#!/bin/bash
# repackage_pro_tools.sh
#
# Delete bloatware from an Avid Pro Tools .dmg installer disk image.
# We build a new Pro Tools installer .pkg with components deleted.
# This is for local install use only. It is not intended to be
# re-signed or redistributed.
###
# MIT License
#
# Copyright (c) 2026 Darryl Ramm
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
###
# Made with wonderful assistance from Anthropic Claude
###

set -euo pipefail

GIT_TAG_VERSION="@@@VERSION@@@"

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h] [-v] [-k] input_dmg [output_dir]

  -h    help. Show this help and exit.
  -v    version. Print the script version and exit.
  -k    keep. Keep the unpacked workspace in /tmp/pt_repackage_workspace
	instead of deleting it. This is for development only.

  input_dmg    Path to the Pro Tools installer .dmg (required).
  output_dir   Where to write the cleaned .pkg and staged companion
               installers. Defaults to the same directory as input_dmg.

 Note: On subsequent -k runs against the same dmg (same path, size,
       and mtime), the user is given the option to reuse the previous
       unpacked content. But previous runs will have removed compnents
       they were told to. In some cases this will cause this script
       to fail for example if it's asked to redo an edit on an xml
       file that was already done.

EOF
}

KEEP_WORKSPACE=false
while getopts ":hvk" opt; do
    case "${opt}" in
        h) usage; exit 0 ;;
        v) echo "${GIT_TAG_VERSION}"; exit 0 ;;
        k) KEEP_WORKSPACE=true ;;
        \?) echo "Unknown option: -${OPTARG}" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

INPUT_DMG="${1:-}"

dmg_filename_regex='^Pro_Tools_[0-9]+\.[0-9]+(\.[0-9]+)?_Mac\.dmg$'

if [[ -z "${INPUT_DMG}" ]]; then
    echo "Usage: $0 /path/to/Pro_Tools_Installer.dmg"
    exit 1
fi

DMG_BASENAME="$(basename "${INPUT_DMG}")"

# nocasematch is scoped tightly to this one check and immediately reverted —
# left on globally it would quietly make every later [[ ... ]] comparison in
# the script case-insensitive, including the true/false flag checks below.
shopt -s nocasematch
DMG_NAME_MATCHES=false
[[ "${DMG_BASENAME}" =~ ${dmg_filename_regex} ]] && DMG_NAME_MATCHES=true
shopt -u nocasematch

if [[ "${DMG_NAME_MATCHES}" != true ]]; then
    echo "ERROR: Expected a Pro Tools Installer .dmg file with name like \"Pro_Tools_2026.4.1_Mac.dmg\""
    usage
    exit 1
fi

if [[ ! -f "${INPUT_DMG}" ]]; then
    echo "Error: Input DMG file not found: '${INPUT_DMG}'"
    echo "Usage: $0 /path/to/Pro_Tools_Installer.dmg (e.g. $0 Pro_Tools_2026.4.1_Mac.dmg)"
    exit 1
fi

INSTALLER_VERSION="${DMG_BASENAME#Pro_Tools_}"
INSTALLER_VERSION="${INSTALLER_VERSION%_Mac.dmg}"

#echo "INSTALLER_VERSION = \"${INSTALLER_VERSION}\""

SOURCE_DIR="$(cd "$(dirname "${INPUT_DMG}")" && pwd)"
OUTPUT_DIR="${2:-${SOURCE_DIR}}"

WORKSPACE="/tmp/pt_repackage_workspace"
MOUNT_DIR="${WORKSPACE}/mnt"
EXPAND_DIR="${WORKSPACE}/expanded"
PAYLOAD_DIR="${WORKSPACE}/payload_extracted"
STATE_FILE="${WORKSPACE}/.repack_state"

# ========================================================================
# EXACT PATH AUDIT LIST (per paths.md — do not edit without updating spec):
# -- UPDATE from PATHS.md - Darryl
# ========================================================================

APP_PKG_DIR="${EXPAND_DIR}/Pro Tools Application.pkg"
SCRIPTS_DIR="${APP_PKG_DIR}/Scripts"
DISTRIBUTION_XML="${EXPAND_DIR}/Distribution"

AVID_LINK_PKG="${SCRIPTS_DIR}/AvidLink_Installer.pkg"
AVID_LINK_ALT="${SCRIPTS_DIR}/._AvidLink_Installer.pkg"
APPMAN_PKG="${EXPAND_DIR}/Pro Tools AppMan.pkg"
SOUNDFLOW_PKG="${SCRIPTS_DIR}/SoundFlowProTools.pkg"
SPLICE_PKG="${SCRIPTS_DIR}/SpliceProTools.pkg"
MELODYNE_PKG="${SCRIPTS_DIR}/Melodyne.pkg"
MELODYNE_ALT="${SCRIPTS_DIR}/._Melodyne.pkg"

SKETCH_PLUGIN="${PAYLOAD_DIR}/Applications/Pro Tools.app/Contents/PlugIns/System Plug-Ins/Pro Tools Sketch.aaxplugin"
GO_SKETCH_DIR="${PAYLOAD_DIR}/tmp/Go_Sketch"
VIDEO_ENGINE="${PAYLOAD_DIR}/Applications/Pro Tools.app/Contents/Frameworks/Video Engine"
DEMO_SESSIONS_DIR="${PAYLOAD_DIR}/tmp/Demo_Session"

# mkbom (Xcode Command Line Tools) is only needed to regenerate the Bill of
# Materials after a payload-level edit (Sketch / Video Engine / Demo
# Sessions). Detected once here so those three prompts can be skipped
# cleanly, with an explanation, on a machine without CLT installed — rather
# than failing partway through Phase 4 after the user already answered yes.
MKBOM_AVAILABLE=true
command -v mkbom >/dev/null 2>&1 || MKBOM_AVAILABLE=false

### Functions

humanize_kb() {
    awk -v kb="$1" 'BEGIN {
        if (kb < 1024) printf "%dK", kb;
        else if (kb < 1024*1024) printf "%.1fM", kb/1024;
        else printf "%.2fG", kb/1024/1024;
    }'
}

size_of() {
    # Human-readable size for one or more paths; "0B" if none exist.
    local existing=()
    for p in "$@"; do [[ -e "${p}" ]] && existing+=("${p}"); done
    if [[ ${#existing[@]} -eq 0 ]]; then echo "0B"; return; fi
    du -sch "${existing[@]}" 2>/dev/null | tail -n 1 | awk '{print $1}'
}

prompt_yes_no() {
    local prompt_msg="$1" default_choice="${2:-Y}" choice
    while true; do
        read -rp "${prompt_msg} [y/n] (default ${default_choice}): " choice
        choice="${choice:-${default_choice}}"
        case "${choice}" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

SUDO_EXPLAINED=false
run_privileged() {
    local reason="$1"; shift
    if [[ "${SUDO_EXPLAINED}" == false ]]; then
        echo ""
        echo "Administrator privileges needed: ${reason}"
        sudo -k        # never silently trust an already-cached ticket
        sudo -v        # forces a password prompt now, with the reason above shown
        SUDO_EXPLAINED=true
    fi
    sudo "$@"
}

dmg_fingerprint() {
    local f="$1"
    printf '%s|%s|%s' "$(cd "$(dirname "${f}")" && pwd)/$(basename "${f}")" \
        "$(stat -f%z "${f}")" "$(stat -f%m "${f}")"
}

STRIP_XSL="${WORKSPACE}/strip_pkgref.xsl"
write_strip_xsl() {
    cat > "${STRIP_XSL}" <<'XSLEOF'
<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" encoding="UTF-8" indent="no"/>
  <xsl:param name="target_id"/>
  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>
  <xsl:template match="pkg-ref">
    <xsl:if test="not(@id = $target_id)">
      <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
XSLEOF
}

# Removes ONLY the <pkg-ref> element(s) for a given component from the
# Distribution manifest — NOT the surrounding <choice>/<line>, since a
# choice here can bundle several pkg-refs together (e.g. AppMan sits in
# the same <choice> as the core Pro Tools Application pkg-ref; deleting
# the choice would remove everything, not just the target).
#
# Embedded sub-packages are referenced as "#Percent%20Encoded%20Name.pkg"
# (a leading '#' plus URL-encoding, not a literal filename with spaces),
# so matching is done by pkg-ref/@id substring, which is stable regardless
# of encoding. A given id can legitimately appear on more than one
# <pkg-ref> element (metadata split across duplicates) — xsltproc removes
# every match with that id in one pass; the result is verified afterward.
#
# Node removal is done via xsltproc (identity-transform stylesheet), NOT
# xmllint --shell — that shell has no delete-node command in the libxml2
# versions checked, so an edit that "succeeds" silently does nothing.
strip_distribution_pkg_ref() {
    local match_hint="$1"
    [[ -f "${DISTRIBUTION_XML}" ]] || return 0

    if ! command -v xsltproc >/dev/null 2>&1; then
        echo "   ERROR: xsltproc not found; cannot safely edit Distribution manifest." >&2
        exit 1
    fi

    local ref_id
    ref_id=$(xmllint --xpath "string((//pkg-ref[contains(@id,'${match_hint}')])[1]/@id)" \
        "${DISTRIBUTION_XML}" 2>/dev/null || true)

    if [[ -z "${ref_id}" ]]; then
        echo "    ERROR: no pkg-ref with id containing \"${match_hint}\" found in Distribution." >&2
        echo "    Refusing to delete the file(s) without also removing their manifest entry." >&2
        exit 1
    fi

    [[ -f "${STRIP_XSL}" ]] || write_strip_xsl
    local tmp_out="${DISTRIBUTION_XML}.tmp"
    xsltproc --stringparam target_id "${ref_id}" "${STRIP_XSL}" "${DISTRIBUTION_XML}" > "${tmp_out}"

    if ! xmllint --noout "${tmp_out}" 2>/dev/null; then
        echo "    ERROR: Distribution manifest is no longer well-formed after removing id \"${ref_id}\"." >&2
        echo "    Aborting before flatten — a broken manifest produces a .pkg that will not open." >&2
        rm -f "${tmp_out}"
        exit 1
    fi

    local remaining
    remaining=$(xmllint --xpath "count(//pkg-ref[@id='${ref_id}'])" "${tmp_out}" 2>/dev/null || echo "1")
    if [[ "${remaining}" != "0" ]]; then
        echo "   ERROR: pkg-ref id \"${ref_id}\" still present (${remaining} instance(s)) after removal attempt." >&2
        rm -f "${tmp_out}"
        exit 1
    fi

    mv "${tmp_out}" "${DISTRIBUTION_XML}"
}

cleanup() {
    if hdiutil info 2>/dev/null | grep -q "${MOUNT_DIR}"; then
        hdiutil detach "${MOUNT_DIR}" -quiet -force || true
    fi
    if [[ "${KEEP_WORKSPACE}" != true && -d "${WORKSPACE}" ]]; then
        rm -rf "${WORKSPACE}"
    fi
}
trap cleanup EXIT

### Phase 0: workspace setup / -k reuse detection

REUSE_EXISTING=false
CACHED_FINGERPRINT=""
[[ -f "${STATE_FILE}" ]] && CACHED_FINGERPRINT="$(cat "${STATE_FILE}")"

if [[ "${KEEP_WORKSPACE}" == true && -n "${CACHED_FINGERPRINT}" && -d "${EXPAND_DIR}" ]]; then
    CURRENT_FINGERPRINT="$(dmg_fingerprint "${INPUT_DMG}")"
    if [[ "${CACHED_FINGERPRINT}" == "${CURRENT_FINGERPRINT}" ]]; then
        echo "Found a previously unpacked copy of this DMG from an earlier -k run:"
        echo "  ${EXPAND_DIR}"
        if prompt_yes_no "Reuse it instead of re-unpacking? (it will be missing whatever was removed before)" "Y"; then
            REUSE_EXISTING=true
        fi
    else
        echo "==> A cached unpack exists at ${WORKSPACE}, but its fingerprint doesn't match this DMG:"
        echo "      cached:  ${CACHED_FINGERPRINT}"
        echo "      current: ${CURRENT_FINGERPRINT}"
        echo "    Re-unpacking from scratch."
    fi
elif [[ "${KEEP_WORKSPACE}" == true ]]; then
    echo "==> No cached unpack found for this DMG — unpacking from scratch."
fi

[[ "${REUSE_EXISTING}" != true ]] && rm -rf "${WORKSPACE}"
mkdir -p "${MOUNT_DIR}" "${WORKSPACE}/companions" "${OUTPUT_DIR}"

### Phase 1: mount, locate main pkg, save companions

echo "==> Mounting source DMG at ${MOUNT_DIR}..."
hdiutil attach "${INPUT_DMG}" -mountpoint "${MOUNT_DIR}" -nobrowse -readonly -quiet

PRO_TOOLS_PKG=""
while IFS= read -r pkg; do
    [[ -n "${pkg}" ]] && { PRO_TOOLS_PKG="${pkg}"; break; }
done < <(find "${MOUNT_DIR}" -iname "*Pro Tools*.pkg" \
    ! -iname "*Audio Bridge*" ! -iname "*HD Driver*" \
    ! -iname "*Folder*" ! -iname "*Codecs*" 2>/dev/null || true)

if [[ -z "${PRO_TOOLS_PKG}" ]]; then
    echo "Error: Could not locate primary Pro Tools package inside DMG." >&2
    exit 1
fi

main_pkg_kb=$(du -sk "${PRO_TOOLS_PKG}" | awk '{print $1}')
echo "==> Found primary package: \"$(basename "${PRO_TOOLS_PKG}")\" [$(humanize_kb "${main_pkg_kb}")]"

find "${MOUNT_DIR}" -iname "*.pkg" 2>/dev/null | while read -r pkg; do
    if [[ "${pkg}" != "${PRO_TOOLS_PKG}" ]]; then
        echo "    Saving companion installers: \"$(basename "${pkg}")\" [$(size_of "${pkg}")]"
        cp -R "${pkg}" "${WORKSPACE}/companions/"
    fi
done

### Phase 2: expand + extract payload (skipped on -k reuse)

if [[ "${REUSE_EXISTING}" == true ]]; then
    echo "==> Reusing previously unpacked package/payload for this DMG (-k)."
else
    echo "==> Expanding primary package to ${EXPAND_DIR}..."
    pkgutil --expand "${PRO_TOOLS_PKG}" "${EXPAND_DIR}"

    if find "${EXPAND_DIR}" ! -user "$(id -u)" -print -quit 2>/dev/null | grep -q .; then
        run_privileged "some files extracted from the installer are owned by root and must be reassigned to you before they can be edited or removed" \
            chown -R "$(id -u):$(id -g)" "${EXPAND_DIR}"
    fi

    if [[ -f "${APP_PKG_DIR}/Payload" ]]; then
        mkdir -p "${PAYLOAD_DIR}"
        echo "==> Extracting application payload to ${PAYLOAD_DIR}..."
        ( cd "${PAYLOAD_DIR}" && gzip -dc "${APP_PKG_DIR}/Payload" | cpio -id --quiet )
    fi

    dmg_fingerprint "${INPUT_DMG}" > "${STATE_FILE}"
fi

hdiutil detach "${MOUNT_DIR}" -quiet || true

### Phase 3: interactive selection

echo ""
echo "Select components to remove (default: yes):"
echo ""

if prompt_yes_no "Remove \"Pro Tools AppMan.pkg\" / \"AvidLink_Installer.pkg\" (Avid Link / App Manager)? [$(size_of "${AVID_LINK_PKG}" "${AVID_LINK_ALT}" "${APPMAN_PKG}")]" "Y"; then
    PURGE_AVID_LINK=true; else PURGE_AVID_LINK=false; fi

if prompt_yes_no "Remove \"SoundFlowProTools.pkg\"? [$(size_of "${SOUNDFLOW_PKG}")]" "Y"; then
    PURGE_SOUNDFLOW=true; else PURGE_SOUNDFLOW=false; fi

if prompt_yes_no "Remove \"SpliceProTools.pkg\"? [$(size_of "${SPLICE_PKG}")]" "Y"; then
    PURGE_SPLICE=true; else PURGE_SPLICE=false; fi

if prompt_yes_no "Remove \"Melodyne.pkg\"? [$(size_of "${MELODYNE_PKG}" "${MELODYNE_ALT}")]" "Y"; then
    PURGE_MELODYNE=true; else PURGE_MELODYNE=false; fi

if [[ "${MKBOM_AVAILABLE}" == true ]]; then
    if prompt_yes_no "Remove \"Pro Tools Sketch.aaxplugin\"? [$(size_of "${SKETCH_PLUGIN}" "${GO_SKETCH_DIR}")]" "Y"; then
        PURGE_SKETCH=true; else PURGE_SKETCH=false; fi

    if prompt_yes_no "Remove \"Avid Video Engine\"? [$(size_of "${VIDEO_ENGINE}")]" "Y"; then
        PURGE_VIDEO_ENGINE=true; else PURGE_VIDEO_ENGINE=false; fi

    if prompt_yes_no "Remove Pro Tools Demo Sessions? [$(size_of "${DEMO_SESSIONS_DIR}")]" "Y"; then
        PURGE_DEMO_SESSIONS=true; else PURGE_DEMO_SESSIONS=false; fi
else
    PURGE_SKETCH=false
    PURGE_VIDEO_ENGINE=false
    PURGE_DEMO_SESSIONS=false
    echo ""
    echo "Note: \"mkbom\" isn't installed (it ships with Xcode Command Line"
    echo "Tools, not stock macOS), so these three removals are unavailable"
    echo "this run: Pro Tools Sketch, Avid Video Engine, Demo Sessions."
    echo "Install with: xcode-select --install"
fi

ANY_PURGE=false
for v in "${PURGE_AVID_LINK}" "${PURGE_SOUNDFLOW}" "${PURGE_SPLICE}" \
         "${PURGE_MELODYNE}" "${PURGE_SKETCH}" "${PURGE_VIDEO_ENGINE}" "${PURGE_DEMO_SESSIONS}"; do
    [[ "${v}" == true ]] && ANY_PURGE=true && break
done

if [[ "${ANY_PURGE}" != true ]]; then
    echo ""
    echo "Nothing selected for removal—no changes to make, so no output"
    echo "package was created."
    exit 0
fi

### Phase 4: Component removal

echo ""
echo "==> Removing selected components..."

if [[ "${PURGE_AVID_LINK}" == true ]]; then
    echo "    Removing Avid Link / AppMan..."
    strip_distribution_pkg_ref "AppMan"
    rm -rf "${AVID_LINK_PKG}" "${AVID_LINK_ALT}" "${APPMAN_PKG}"
fi

if [[ "${PURGE_SOUNDFLOW}" == true ]]; then
    echo "    Removing SoundFlow..."
    rm -rf "${SOUNDFLOW_PKG}"
fi

if [[ "${PURGE_SPLICE}" == true ]]; then
    echo "    Removing Splice..."
    rm -rf "${SPLICE_PKG}"
fi

if [[ "${PURGE_MELODYNE}" == true ]]; then
    echo "    Removing Melodyne..."
    rm -rf "${MELODYNE_PKG}" "${MELODYNE_ALT}"
fi

PAYLOAD_MODIFIED=false

if [[ "${PURGE_SKETCH}" == true ]]; then
    [[ -d "${SKETCH_PLUGIN}" ]] && { echo "    Removing Sketch plugin..."; rm -rf "${SKETCH_PLUGIN}"; PAYLOAD_MODIFIED=true; }
    [[ -d "${GO_SKETCH_DIR}" ]] && { echo "    Removing Sketch content ..."; rm -rf "${GO_SKETCH_DIR}"; PAYLOAD_MODIFIED=true; }
fi

if [[ "${PURGE_VIDEO_ENGINE}" == true && -d "${VIDEO_ENGINE}" ]]; then
    echo "    Removing Avid Video Engine framework..."
    rm -rf "${VIDEO_ENGINE}"
    PAYLOAD_MODIFIED=true
fi

if [[ "${PURGE_DEMO_SESSIONS}" == true && -d "${DEMO_SESSIONS_DIR}" ]]; then
    echo "    Removing Pro Tools Demo Sessions..."
    rm -rf "${DEMO_SESSIONS_DIR}"
    PAYLOAD_MODIFIED=true
fi

if [[ "${PAYLOAD_MODIFIED}" == true ]]; then
    echo "==> Repacking payload and regenerating Bom..."
    rm -f "${APP_PKG_DIR}/Payload"
    ( cd "${PAYLOAD_DIR}" && find . -mindepth 1 | cpio -o --format odc --owner 0:80 --quiet | gzip -c ) > "${APP_PKG_DIR}/Payload"

    rm -f "${APP_PKG_DIR}/Bom"
    mkbom "${PAYLOAD_DIR}" "${APP_PKG_DIR}/Bom"

    if [[ -f "${APP_PKG_DIR}/PackageInfo" ]]; then
        payload_kb=$(du -k "${APP_PKG_DIR}/Payload" | cut -f1)
        file_count=$(find "${PAYLOAD_DIR}" | wc -l | tr -d ' ')
        sed -i '' "s/installKBytes=\"[^\"]*\"/installKBytes=\"${payload_kb}\"/" "${APP_PKG_DIR}/PackageInfo" || true
        sed -i '' "s/files=\"[^\"]*\"/files=\"${file_count}\"/" "${APP_PKG_DIR}/PackageInfo" || true
    fi
fi

### Phase 5: flatten + output

OUTPUT_PKG_NAME="Pro_Tools_Install_${INSTALLER_VERSION}_Clean.pkg"
echo "==> Flattening repacked installer..."
pkgutil --flatten "${EXPAND_DIR}" "${OUTPUT_DIR}/${OUTPUT_PKG_NAME}"

if [[ "$(ls -A "${WORKSPACE}/companions" 2>/dev/null)" ]]; then
    cp -R "${WORKSPACE}/companions/"* "${OUTPUT_DIR}/"
fi

repacked_kb=$(du -sk "${OUTPUT_DIR}/${OUTPUT_PKG_NAME}" | awk '{print $1}')
saved_kb=$(( main_pkg_kb - repacked_kb ))

echo ""
echo "Done. \"${OUTPUT_PKG_NAME}\" [$(humanize_kb "${repacked_kb}")] written to:"
echo "  ${OUTPUT_DIR}"
echo "Space saved vs. original: $(humanize_kb "${saved_kb}")"

if [ "$PURGE_SOUNDFLOW" = "true" ] ; then
   echo "Note: The SoundFlow app has been removed but the SoundFlow panel will still be present in the Pro Tools Edit Window right panel (but can be hidden)."
fi

if [ "$PURGE_SPLICE" = "true" ] ; then
   echo "Note: The Splice plugin has been removed but the Splice panel will still be present in the Pro Tools Edit Window right panel (but can be hidden)."
fi
#!/bin/bash

INPUT_DMG="Pro_Tools_26.4.1_Mac.dmg"

INPUT_DMG2="PRo_Tools_26.4.1_MAC.DMG"

INPUT_DMG3="PRo_Tools_12.1_MAC.DMG"

INPUT_DMG4="PRo_Tools.DMG"

INPUT_DMG_EXT="${INPUT_DMG##*.}"

echo "INPUT_DMG        = ${INPUT_DMG}"

regex_pattern='^Pro_Tools_[0-9]*.[0-9]*(.[0-9]*)_Mac.dmg'

shopt -s nocasematch

if [[ "${INPUT_DMG}" =~ ${regex_pattern} ]]; then
    echo "Match found!"
else
    echo "No match."
fi

if [[ "${INPUT_DMG2}" =~ ${regex_pattern} ]]; then
    echo "Match found!"
else
    echo "No match."
fi

if [[ "${INPUT_DMG3}" =~ ${regex_pattern} ]]; then
    echo "Match found!"
else
    echo "No match."
fi

if [[ "${INPUT_DMG4}" =~ ${regex_pattern} ]]; then
    echo "Match found!"
else
    echo "No match."
fi

#!/usr/bin/env bash
# install.sh - link dotfiles into $HOME with plain symlinks. Idempotent: safe to re-run.
#
#   ./install.sh [--dry-run] [--verify] [--backup] [--no-plugins] [--yes] [--category CAT]... [pkg...]
#   ./install.sh --remove [--category CAT]... [pkg...]
#
# Manifest format (one table, no separate category map):
#   "category kind pkg src dest"
#   kind: dir  = link $REPO/<src>      -> $HOME/<dest>   (whole directory)
#         tree = link $REPO/<src>/*    -> $HOME/<dest>/  (children, for shared dirs like .config, ., .local/bin)
#         file = link $REPO/<src>      -> $HOME/<dest>   (single file)

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

MANIFEST=(
    "core   dir   hypr        hypr              .config/hypr"
    "core   dir   quickshell  quickshell        .config/quickshell"
    "core   dir   foot        foot              .config/foot"
    "core   tree  zsh         zsh               ."
    "core   tree  starship    starship          .config"
    "core   dir   tmux        tmux              .config/tmux"
    "core   file  git         .gitconfig        .gitconfig"
    "core   tree  bin         bin               .local/bin"
    "extras dir   bat         bat               .config/bat"
    "extras dir   btop        btop              .config/btop"
    "extras dir   fastfetch   fastfetch         .config/fastfetch"
    "extras dir   lazygit     lazygit           .config/lazygit"
    "extras dir   nvim        nvim              .config/nvim"
    "extras dir   mise        mise              .config/mise"
    "extras dir   yazi        yazi              .config/yazi"
    "extras tree  agents      agents            .agents"
    "extras file  agents      agents/AGENTS.md  .config/opencode/AGENTS.md"
    "extras file  agents      agents/skills     .config/opencode/skills"
    "extras file  agents      agents/AGENTS.md  .pi/agent/AGENTS.md"
)

DRY_RUN=0 VERIFY=0 BACKUP=0 NO_PLUGINS=0 ASSUME_YES=0
BACKUP_DIR="${DOT_BACKUP_DIR:-$HOME/.local/share/dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"
MODE=install
SEL_CATS=()
SEL_PKGS=()

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
dry()  { printf '  \033[1;33mdry-run\033[0m %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

categories() { printf '%s\n' "${MANIFEST[@]}" | awk '{print $1}' | sort -u; }
pkgs_in()    { local c=$1; printf '%s\n' "${MANIFEST[@]}" | awk -v c="$c" '$1==c {print $3}' | sort -u | tr '\n' ' ' | sed 's/ $//'; }

usage() {
    sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    printf 'options:\n'
    printf '  -n, --dry-run    print actions without changing anything\n'
    printf '  --verify         check links only, exit non-zero on mismatch\n'
    printf '  --backup         move unmanaged files aside instead of skipping\n'
    printf '  --no-plugins     skip mise install and theme reload hooks\n'
    printf '  -y, --yes        never prompt\n'
    printf '  -C, --category CAT  only this category (repeatable)\n'
    printf 'categories:\n'
    while read -r c; do printf '  %s: %s\n' "$c" "$(pkgs_in "$c")"; done < <(categories)
}

while (($#)); do
    case "$1" in
        -R|--remove) MODE=remove ;;
        -n|--dry-run) DRY_RUN=1 ;;
        --verify) VERIFY=1; DRY_RUN=1 ;;
        --backup) BACKUP=1 ;;
        --no-plugins) NO_PLUGINS=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        -C|--category|--only)
            [ $# -ge 2 ] || die "$1 needs a category name"
            grep -qx "$2" < <(categories) || die "unknown category: $2"
            SEL_CATS+=("$2"); shift ;;
        -h|--help) usage; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *) SEL_PKGS+=("$1") ;;
    esac
    shift
done

known_pkgs=$(printf '%s\n' "${MANIFEST[@]}" | awk '{print $3}' | sort -u)
for p in ${SEL_PKGS[@]+"${SEL_PKGS[@]}"}; do grep -qx "$p" <<<"$known_pkgs" || die "unknown package: $p"; done

selected() {
    local cat=$1 pkg=$2 c p
    if ((${#SEL_CATS[@]} == 0 && ${#SEL_PKGS[@]} == 0)); then return 0; fi
    for c in ${SEL_CATS[@]+"${SEL_CATS[@]}"}; do [ "$c" = "$cat" ] && return 0; done
    for p in ${SEL_PKGS[@]+"${SEL_PKGS[@]}"}; do [ "$p" = "$pkg" ] && return 0; done
    return 1
}

FAIL=0
mismatch() { printf '  \033[1;31mmismatch\033[0m %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
rel() { printf '%s' "${1#"$HOME"/}"; }

is_link_to() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$2" ]; }

back_up() {
    local dest=$1 target="$BACKUP_DIR/$(rel "$1")"
    if [ "$DRY_RUN" -eq 1 ]; then dry "would back up $(rel "$dest")"; return 0; fi
    mkdir -p "$(dirname "$target")"
    mv "$dest" "$target"
    log "backed up $(rel "$dest")"
}

put_link() {
    local src=$1 dest=$2
    if [ "$VERIFY" -eq 1 ]; then
        is_link_to "$dest" "$src" || mismatch "$(rel "$dest") should link to $src"
        return 0
    fi
    [ "$DRY_RUN" -eq 0 ] && mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ]; then
        is_link_to "$dest" "$src" && return 0
        warn "$(rel "$dest") is a foreign symlink - skipping"
    elif [ -e "$dest" ]; then
        if [ "$BACKUP" -eq 1 ]; then back_up "$dest"; else
            warn "$(rel "$dest") holds unmanaged content - skipping (re-run with --backup)"
            return 0
        fi
    fi
    if [ "$DRY_RUN" -eq 1 ]; then dry "would link $(rel "$dest") -> $src"; return 0; fi
    ln -sfn "$(realpath --relative-to="$(dirname "$dest")" "$src")" "$dest"
}

is_shared() {
    case "${1//\/.\//\/}" in
        "$HOME"|"$HOME/.config"|"$HOME/.local"|"$HOME/.local/bin"|"$HOME/.local/share"|"$HOME/.local/share/themes") return 0 ;;
    esac
    return 1
}

fully_managed() {
    local dir=$1 e
    [ -d "$dir" ] && [ ! -L "$dir" ] || return 1
    while IFS= read -r -d '' e; do
        [ -L "$e" ] || return 1
        case "$(readlink -f "$e")" in "$REPO"/*) ;; *) return 1 ;; esac
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0)
    return 0
}

try_fold() {
    local dir=$1 src=$2
    is_shared "$dir" && return 1
    fully_managed "$dir" || return 1
    if [ "$DRY_RUN" -eq 1 ]; then dry "would fold $(rel "$dir") -> $src"; return 0; fi
    if [ "$VERIFY" -eq 1 ]; then return 0; fi
    find "$dir" -mindepth 1 -maxdepth 1 -delete
    rmdir "$dir"
    ln -s "$(realpath --relative-to="$(dirname "$dir")" "$src")" "$dir"
}

link_dir() {
    local pkg=$1 dest="$HOME/$2" src="$REPO/$1"
    if [ "$VERIFY" -eq 1 ]; then
        is_link_to "$dest" "$src" || mismatch "$2 should link to $src"
        return 0
    fi
    [ "$DRY_RUN" -eq 0 ] && mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ]; then
        put_link "$src" "$dest"
    elif [ -e "$dest" ]; then
        if try_fold "$dest" "$src"; then
            [ "$DRY_RUN" -eq 0 ] && log "folding $2"
        elif [ "$BACKUP" -eq 1 ]; then
            back_up "$dest"; put_link "$src" "$dest"
        else
            warn "$2 holds unmanaged content - skipping $pkg (re-run with --backup)"
        fi
    else
        put_link "$src" "$dest"
    fi
}

link_children() {
    local src="$REPO/$1" dst="$HOME/$2" entry name sub
    if [ "$VERIFY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then mkdir -p "$dst"; fi
    while IFS= read -r -d '' entry; do
        name="$(basename "$entry")"; sub="$dst/$name"
        if [ -d "$entry" ] && [ ! -L "$entry" ]; then
            if [ -L "$sub" ] || [ ! -e "$sub" ]; then
                put_link "$entry" "$sub"
            elif try_fold "$sub" "$entry"; then
                [ "$DRY_RUN" -eq 0 ] && [ "$VERIFY" -eq 0 ] && log "folding $(rel "$sub")"
            elif [ -d "$sub" ] && { is_shared "$sub" || ! fully_managed "$sub"; }; then
                link_children "${entry#"$REPO"/}" "${sub#"$HOME"/}"
            else
                put_link "$entry" "$sub"
            fi
        else
            put_link "$entry" "$sub"
        fi
    done < <(find "$src" -mindepth 1 -maxdepth 1 -print0 | sort -z)
}

rm_link() {
    local dest=$1 label=$2
    if [ -L "$dest" ]; then
        case "$(readlink -f "$dest")" in
            "$REPO"/*)
                if [ "$DRY_RUN" -eq 1 ]; then dry "would remove $(rel "$dest")"; else rm "$dest"; log "removed $(rel "$dest")"; fi ;;
            *) warn "$(rel "$dest") is a foreign symlink - leaving it ($label)" ;;
        esac
    elif [ -e "$dest" ]; then
        warn "$(rel "$dest") holds unmanaged content - leaving it ($label)"
    fi
}

rm_dir() {
    local dest="$HOME/$2" pkg=$1
    if [ -L "$dest" ]; then rm_link "$dest" "$pkg"
    elif [ -d "$dest" ] && fully_managed "$dest"; then
        if [ "$DRY_RUN" -eq 1 ]; then dry "would remove $(rel "$dest")"
        else find "$dest" -mindepth 1 -maxdepth 1 -delete; rmdir "$dest"; log "removed $(rel "$dest")"; fi
    elif [ -e "$dest" ]; then
        warn "$(rel "$dest") holds unmanaged content - leaving it ($pkg)"
    fi
}

rm_children() {
    local src="$REPO/$1" dst="$HOME/$2" entry name sub
    while IFS= read -r -d '' entry; do
        name="$(basename "$entry")"; sub="$dst/$name"
        if [ -L "$sub" ]; then
            rm_link "$sub" "$name"
        elif [ -d "$sub" ] && [ -d "$entry" ] && [ ! -L "$entry" ]; then
            if fully_managed "$sub" && ! is_shared "$sub"; then
                if [ "$DRY_RUN" -eq 1 ]; then dry "would remove $(rel "$sub")"
                else find "$sub" -mindepth 1 -maxdepth 1 -delete; rmdir "$sub"; fi
            else
                rm_children "${entry#"$REPO"/}" "${sub#"$HOME"/}"
            fi
        elif [ -e "$sub" ]; then
            warn "$(rel "$sub") is not ours - leaving it"
        fi
    done < <(find "$src" -mindepth 1 -maxdepth 1 -print0 | sort -z)
}

if [ "$MODE" = remove ]; then log "unlinking packages from $REPO"; else log "installing dotfiles from $REPO"; fi

count=0
for entry in "${MANIFEST[@]}"; do
    read -r cat kind pkg src dest <<<"$entry"
    selected "$cat" "$pkg" || continue
    case "$MODE:$kind" in
        install:dir)  link_dir "$src" "$dest" ;;
        install:tree) link_children "$src" "$dest" ;;
        install:file) put_link "$REPO/$src" "$HOME/$dest" ;;
        remove:dir)   rm_dir "$pkg" "$dest" ;;
        remove:tree)  rm_children "$src" "$dest" ;;
        remove:file)  rm_link "$HOME/$dest" "$pkg" ;;
    esac
    count=$((count + 1))
done

if [ "$VERIFY" -eq 1 ]; then
    [ "$FAIL" -eq 0 ] && log "verified $count item(s)" || warn "verified $count item(s) with $FAIL mismatch(s)"
    exit "$([ "$FAIL" -eq 0 ] && echo 0 || echo 1)"
fi
if [ "$MODE" = remove ]; then log "unlinked $count item(s)"; exit 0; fi
if [ "$DRY_RUN" -eq 1 ]; then log "dry-run: $count item(s), nothing changed"; exit 0; fi
log "linked $count item(s)"

if selected core git && [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ] && [ -f "$REPO/.gitconfig" ]; then
    log "git identity: $(git config --file "$REPO/.gitconfig" user.name 2>/dev/null || echo '(unset)') <$(git config --file "$REPO/.gitconfig" user.email 2>/dev/null || echo '(unset)')>"
    read -r -p "Edit .gitconfig now? [y/N] " reply || true
    case "${reply:-}" in [Yy]*) "${EDITOR:-vi}" "$REPO/.gitconfig" || warn "editor exited non-zero" ;; esac
fi

if [ "$NO_PLUGINS" -eq 0 ]; then
    if selected extras mise && command -v mise >/dev/null 2>&1; then
        mise trust "$REPO/mise/config.toml" >/dev/null 2>&1 && log "trusted mise config" || warn "mise trust failed"
        mise install || warn "mise install failed"
    fi
fi

if [ -x "$REPO/bin/theme" ]; then
    if [ "$NO_PLUGINS" -eq 0 ]; then
        "$REPO/bin/theme" apply >/dev/null 2>&1 && log "applied theme" || warn "theme apply failed"
    else
        "$REPO/bin/theme" apply --no-hooks >/dev/null 2>&1 && log "applied theme" || warn "theme apply failed"
    fi
fi

missing=0
for bin in hyprctl quickshell foot nvim tmux zsh starship lazygit \
           yazi eza bat fd btop wl-copy wl-paste cliphist jq mise \
           brightnessctl hyprsunset notify-send pipewire fastfetch upower loginctl; do
    command -v "$bin" >/dev/null 2>&1 || { printf '  \033[1;31m%s\033[0m missing\n' "$bin"; missing=1; }
done
[ "$missing" -eq 0 ] || warn "some requirements are missing - see README.md (pkglist.txt)"

cat <<EOF

done. next steps:
  exec zsh
  chsh -s /usr/bin/zsh
  hyprctl reload
EOF

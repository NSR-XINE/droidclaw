#!/data/data/com.termux/files/usr/bin/bash
set -e

RST='\033[0m'
GRN='\033[0;32m'
YLW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
BLD='\033[1m'
TEL='\033[0;36m'

clear

echo ""
echo -e "${TEL}  ╭─────────────────────────────────╮${RST}"
echo -e "${TEL}  │  ◈  K I R A  —  Install        │${RST}"
echo -e "${TEL}  ╰─────────────────────────────────╯${RST}"
echo ""
echo -e "${DIM}  Built on a Samsung A13 by an 18-year-old in India.${RST}"
echo -e "${DIM}  Runs entirely on your Android phone via Termux.${RST}"
echo ""

if [ ! -d "/data/data/com.termux" ]; then
  echo -e "${RED}  ✕ This must be run inside Termux.${RST}"
  echo -e "${DIM}  Install Termux from F-Droid: f-droid.org/en/packages/com.termux/${RST}"
  exit 1
fi

echo -e "${GRN}[1/5]${RST} Updating packages..."
pkg update -y -q 2>/dev/null || true
echo -e "      ${GRN}✓${RST}"

echo -e "${GRN}[2/5]${RST} Installing dependencies..."
pkg install -y -q nodejs git curl 2>/dev/null || {
  echo -e "${RED}  ✕ Failed to install dependencies.${RST}"
  echo -e "${DIM}  Try: pkg install nodejs git curl${RST}"
  exit 1
}
echo -e "      ${GRN}✓${RST} nodejs $(node --version)"

echo -e "${GRN}[3/5]${RST} Getting Kira..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -d "$SCRIPT_DIR/src" ]; then
  DROIDCLAW="$SCRIPT_DIR"
  echo -e "      using current repository at $DROIDCLAW"
elif [ -d "$HOME/droidclaw/.git" ]; then
  DROIDCLAW="$HOME/droidclaw"
  echo -e "      existing install — updating..."
  cd "$DROIDCLAW"
  git pull -q origin main 2>/dev/null || echo -e "      ${YLW}⚠ using existing version${RST}"
else
  DROIDCLAW="$HOME/droidclaw"
  [ -d "$DROIDCLAW" ] && mv "$DROIDCLAW" "${DROIDCLAW}_backup_$(date +%s)"
  git clone -q https://github.com/NSR-XINE/droidclaw.git "$DROIDCLAW" || {
    echo -e "${RED}  ✕ Clone failed. Check your connection.${RST}"
    exit 1
  }
fi
echo -e "      ${GRN}✓${RST}"

cd "$DROIDCLAW"

echo -e "${GRN}[4/5]${RST} Installing node modules..."
npm install -q --no-audit --no-fund 2>/dev/null || {
  echo -e "${RED}  ✕ npm install failed.${RST}"
  echo -e "${DIM}  Try: cd $DROIDCLAW && npm install${RST}"
  exit 1
}
echo -e "      ${GRN}✓${RST}"

echo -e "${GRN}[5/5]${RST} Setting up kira command..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.droidclaw"

cp "$DROIDCLAW/bin/kira" "$HOME/.local/bin/kira"
chmod +x "$HOME/.local/bin/kira"
if command -v termux-fix-shebang >/dev/null 2>&1; then
  termux-fix-shebang "$HOME/.local/bin/kira" 2>/dev/null || true
fi

if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ] && [ -w "$PREFIX/bin" ]; then
  cp "$DROIDCLAW/bin/kira" "$PREFIX/bin/kira"
  chmod +x "$PREFIX/bin/kira"
  if command -v termux-fix-shebang >/dev/null 2>&1; then
    termux-fix-shebang "$PREFIX/bin/kira" 2>/dev/null || true
  fi
fi

for RC in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
  if [ -f "$RC" ] && ! grep -q '\.local/bin' "$RC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
  fi
done
export PATH="$HOME/.local/bin:$PATH"

echo -e "      ${GRN}✓${RST}"

echo ""
echo -e "  ${BLD}Done.${RST}"
echo ""
echo -e "  ${YLW}kira${RST}           start"
echo -e "  ${YLW}kira status${RST}    what Kira's been thinking"
echo -e "  ${YLW}kira logs${RST}      daemon log"
echo -e "  ${YLW}kira stop${RST}      stop daemon"
echo ""
echo -e "  ${DIM}For full features:${RST}"
echo -e "  ${DIM}· Termux:API — f-droid.org/en/packages/com.termux.api/${RST}"
echo -e "  ${DIM}· KiraService — github.com/levilyf/droidclaw/releases${RST}"
echo ""
echo -e "  ${TEL}Type 'kira' to begin.${RST}"
echo ""

#!/bin/bash
set -e

BUMP_TYPE="${1:-patch}"

if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch|build)$ ]]; then
  echo "Usage: $0 [major|minor|patch|build]"
  exit 1
fi

CURRENT=$(grep '^version=' module.prop | cut -d'=' -f2 | tr -d 'v')
IFS='.' read -r MAJOR MINOR PATCH BUILD <<< "$CURRENT"

case $BUMP_TYPE in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0; BUILD=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0; BUILD=0 ;;
  patch) PATCH=$((PATCH + 1)); BUILD=0 ;;
  build) BUILD=$((BUILD + 1)) ;;
esac

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}.${BUILD}"
NEW_VERSION_CODE=$((10#$MAJOR * 1000000 + 10#$MINOR * 10000 + 10#$PATCH * 100 + 10#${BUILD:-0}))

# Get commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  COMMITS=$(git log --oneline "$LAST_TAG"..HEAD --pretty=format:"%an|%h|%s" | grep -v -E "^github-actions|Bump version" | sed 's/^[^|]*|\([^|]*\)|/- \1 /')
else
  COMMITS=$(git log --oneline --pretty=format:"%an|%h|%s" | head -10 | grep -v -E "^github-actions|Bump version" | sed 's/^[^|]*|\([^|]*\)|/- \1 /')
fi

# Prepend to CHANGELOG.md
if [ -n "$COMMITS" ]; then
  TEMP_CHANGELOG=$(mktemp)
  {
    echo "## $NEW_VERSION"
    echo ""
    echo "$COMMITS"
    echo ""
    cat CHANGELOG.md
  } > "$TEMP_CHANGELOG"
  mv "$TEMP_CHANGELOG" CHANGELOG.md
  echo "Added changelog entry for $NEW_VERSION"
fi

# Update module.prop
sed -i "s/^version=.*/version=$NEW_VERSION/" module.prop
sed -i "s/^versionCode=.*/versionCode=$NEW_VERSION_CODE/" module.prop

# Update update.json
jq --arg v "$NEW_VERSION" --argjson vc "$NEW_VERSION_CODE" \
  '.version = $v | .versionCode = $vc | .zipUrl = "https://github.com/gbthui/magisk-tailscaled/releases/download/\($v)/Magisk-Tailscaled-\($v).zip" | .changelog = "https://raw.githubusercontent.com/gbthui/magisk-tailscaled/main/CHANGELOG.md"' \
  update.json > update.json.tmp && mv update.json.tmp update.json

echo "Bumped $BUMP_TYPE: v$CURRENT → $NEW_VERSION (code: $NEW_VERSION_CODE)"
echo ""
echo "Next steps:"
echo "  git add module.prop update.json CHANGELOG.md"
echo "  git commit -m 'Bump version to $NEW_VERSION'"
echo "  git tag $NEW_VERSION"
echo "  git push && git push --tags"


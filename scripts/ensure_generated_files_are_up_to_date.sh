set -ex

#scripts/l10n/import_l10n_strings_from_poeditor.sh
# scripts/l10n/extract_l10n_strings.sh - Commented out as it requires Xcode's genstrings tool which is not available here
#pod install

git status
git --no-pager diff
git diff-files --name-only --exit-code

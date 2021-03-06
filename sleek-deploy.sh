remote=${1:-staging}
branch=$(git symbolic-ref --short HEAD)
root=$(git rev-parse --show-toplevel)

# TODO: confirm production pushes y/n

echo "Deploying $branch to $remote...\n"

# Make sure we're in the GIT root
cd $root

# Make sure working directory is clean
if [ -n "$(git status --porcelain)" ]; then
	echo "ERROR: Working directory not clean - refuse to deploy\n"
	git status
	exit 1
fi

if [ -n "$(git diff origin/$branch..HEAD)" ]; then
	echo "ERROR: Working directory not clean - refuse to deploy\n"
	git status
	exit 1
fi

# TODO: Make sure remote exists https://stackoverflow.com/questions/12170459/check-if-git-remote-exists-before-first-push
# if [ git ls-remote --exit-code $remote ]; then
# 	echo "ERROR: Remote $remote does not exist\n"
# 	git remote -v
# 	exit 1
# fi

# Make sure this is a sleek-next project
if [ -d wp-content/themes/sleek/acf ]; then
	echo "ERROR: This appears to be an old sleek project - run \$ git push production master instead"
	exit 1
fi

# Copy each .prodignore to .gitignore
for prodignore in $(find . -name '.prodignore'); do
	gitignore=$(echo $prodignore | sed 's/prodignore/gitignore/')
	mv $prodignore $gitignore
done

# Remove all files from GIT but keep them in the filesystem
git rm -r --cached --quiet .

# Move into sleek directory
cd wp-content/themes/sleek

# Make sure dependencies are installed
if ! [ -f vendor/autoload.php ]; then
	composer install
fi

if ! [ -d node_modules ]; then
	npm install
fi

# Build production assets
if ! [ -d dist/assets/fontello ]; then
	npm run fontello
	npm run build
else
	npm run build
fi

# Delete potential nested git repositories in vendor
find vendor -type d | grep .git | xargs rm -rf

# Make sure we're in the GIT root again (in case sleek is installed as a submodule)
cd $root

# Re-add all files (now with .prodignore), commit and push
git add --all
git commit --quiet -m 'Sleek Deploy'
git push --quiet --force $remote $branch # TODO: Don't use --force... use separate release branch always?

# Reset master
git reset HEAD~
git reset --hard HEAD

echo "Deployed $branch to $remote!"

# With different branch
# remote=${1:-staging}
# root=$(git rev-parse --show-toplevel)
#
# # Make sure we're in the GIT root
# cd $root
#
# # Make sure working directory is clean
# if [ -n "$(git status --porcelain)" ]; then
# 	echo "ERROR: Working directory not clean - refuse to deploy\n"
# 	git status
# 	exit 1
# fi
#
# # Create prod branch
# # https://stackoverflow.com/questions/26961371/switch-on-another-branch-create-if-not-exists-without-checking-if-already-exi
# # git checkout sleek_deploy || git checkout -b sleek_deploy && git merge master
# # https://stackoverflow.com/questions/2862590/how-to-replace-master-branch-in-git-entirely-from-another-branch
# git checkout -b sleek_tmp_build
#
# # Copy each .prodignore to .gitignore
# for prodignore in $(find . -name '.prodignore'); do
# 	gitignore=$(echo $prodignore | sed 's/prodignore/gitignore/')
# 	mv $prodignore $gitignore
# done
#
# # Remove all files from GIT but keep them in the filesystem
# git rm -r --cached .
#
# # Move into sleek directory
# cd wp-content/themes/sleek
#
# # Make sure dependencies are installed
# composer install
# npm install
#
# # Build production assets
# npm run build
#
# # Re-add all files (now with .prodignore), commit and push
# git add --all
# git commit -m 'Sleek Deploy'
# git push $remote sleek_tmp_build
#
# # Go back to master and delete temp branch
# git checkout master
# git branch -d sleek_tmp_build
# git push $remote --delete sleek_tmp_build
#
# echo "Deployed to $remote!"

#!/usr/bin/env bash
# build the docs
cd docs
make clean
make html
cd ..

# switch branches and pull the data we want
git checkout --orphan gh-pages
rm -rf .
touch .nojekyll
git checkout doc_updates docs/build/html
mv ./docs/build/html/* ./
rm -rf ./docs
git add -A
git commit -m "publishing updated docs..."
git push upstream gh-pages
# switch back
git checkout doc_updates
# Cloud Design Patterns Journey

Static documentation site for Cloud Deisgn Patterns learning journey.

## How to contribute

1. Clone this repository:
    ```sh
    git clone https://github.com/cloud-design-patterns-journey/docs
    cd docs
    ```
2. Create your own branch from `main`:
    ```sh
    export BRANCH_NAME=<changeme>
    git checkout -b $BRANCH_NAME
    ```
3. Add your doc(s) as `.md` file(s) in the `docs` folder.
4. Update the `nav` section of `mkdocs.yaml` to reference your new docs.
5. Commit and push your changes:
    ```sh
    git add mkdocs.yaml docs
    git commit -s -m '<CHANGEME>'
    git push -u origin $BRANCH_NAME
    ```
6. Create a [new pull request](https://github.com/cloud-design-patterns-journey/docs/compare) by selecting `base:main` and `compare:$BRANCH_NAME`, then click `Create pull request`.
7. After all checks have passed, click `Merge` then `Delete branch`.
8. *Optional*: After PR is closed, you can clear you local changes:
    ```sh
    git checkout main
    git pull
    git branch -d $BRANCH_NAME
    ```

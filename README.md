# HOSTED LIVE, BUT ON STATIC SITE WHICH ONLY UPDATES ON COMMIT
Link here: https://5jayarama.github.io/GithubRepoGrowthGraph/

# HOW TO RUN THIS REPO LOCALLY:
1. If data.json is already up to date
cd into the repo folder
run python -m http.server 8000
type http://localhost:8000/index.html into the chrome browser
2. If data.json is not up to date
cd into the repo folder
make sure .env has a working github api token. It will still work otherwise, but it will be much slower.
run .\update-data.ps1. Wait for it to finish. It will take about 10 minutes.
run python -m http.server 8000
type http://localhost:8000/index.html into the chrome browser

# FILES:
update-data.ps1 is the terminal command in a file which fetches the github data and writes it to data.json.
data.json is the github data. It is a data file.
index.html is the website frontend. It contains both the html and css. 
.env is where the github api token is stored. It will not be on the public repo.

update-data.ps1 notes
1. Fetches new-repos-per-month from GitHub Search API and maintains data.json in the same folder as this script. Re-checks EVERY month's data on every run (not just new/current ones) because past-month counts can drift downward over time as repos get deleted or made private. Meant to run daily.
2. Reads the token from a .env file in the same folder (GITHUB_TOKEN=...).

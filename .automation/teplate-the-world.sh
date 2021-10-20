#!/bin/bash
################################################################################
################################################################################
####### Template all Repos in org @AdmiralAwkbar ###############################
################################################################################
################################################################################

# LEGEND:
# This script will use pagination and the github API to collect a list
# of all repos for an organization.
# It will then check for PRs that it would have created, if not found,
# it will create a Pull Request on the repository to help install
# templates to help make the repository better
#
# PREREQS:
# You need to have the following to run this script successfully:
# - GitHub Personal Access Token with access to the Organization
# - Name of the Organization to query
# - jq installed on the machine running the query
#

###########
# GLOBALS #
###########
GITHUB_API='https://api.github.com' # API URL
GRAPHQL_URL="$GITHUB_API/graphql"   # URL endpoint to graphql
PAGE_SIZE=100      # Default is 100, GitHub limit is 100
END_CURSOR='null'  # Set to null, will be updated after call
TOTAL_REPO_COUNT=0 # Counter of all repos found
ORG_REPOS=()       # Array of all repos found in Org
DEBUG=''           # Set to 'true' to enable debugging

#################
# Template info #
#################
WORKFLOW_TEMPLATE='.automation/template-bot-issue-ops.yml' # Location of the template to add
TEMPLATE_NAME="template-bot-issue-ops.yml"                 # Name of the template file

#####################
# Pull request body #
#####################
PR_BODY="body/pull-request-body.md" # The Pulll Request Body template to pull into the pull request
PR_BODY_STRING=''                   # Converted file into string format

################################################################################
############################ FUNCTIONS #########################################
################################################################################
################################################################################
#### Function Header ###########################################################
Header()
{
  echo ""
  echo "######################################################"
  echo "######################################################"
  echo "########## GitHub Organization TemplateBot ###########"
  echo "######################################################"
  echo "######################################################"
  echo ""
}
################################################################################
#### Function GetRepos #########################################################
GetRepos()
{
  #######################
  # Debug To see cursor #
  #######################
  Debug "DEBUG --- End Cursor:[${END_CURSOR}]"

  #####################################
  # Grab all the data from the system #
  #####################################
  DATA_BLOCK=$(curl -s -X POST \
    -H "authorization: Bearer ${GITHUB_PAT}" \
    -H "content-type: application/json" \
    -d "{\"query\":\"query { organization(login: ${ORG_NAME}) { repositories(first: ${PAGE_SIZE}, after: ${END_CURSOR}) { nodes { name } pageInfo { hasNextPage endCursor }}}}\"}" \
    "${GRAPHQL_URL}" 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to gather data from GitHub!"
    exit 1
  fi

  #########################
  # DEBUG show data block #
  #########################
  Debug "DEBUG --- DATA BLOCK:[${DATA_BLOCK}]"

  ##########################
  # Get the Next Page Flag #
  ##########################
  NEXT_PAGE=$(echo "${DATA_BLOCK}" | jq .[] | jq -r '.organization.repositories.pageInfo.hasNextPage')
  Debug "DEBUG --- Next Page:[${NEXT_PAGE}]"

  ##############################
  # Get the Current End Cursor #
  ##############################
  END_CURSOR=$(echo "${DATA_BLOCK}" | jq .[] | jq -r '.organization.repositories.pageInfo.endCursor')
  Debug "DEBUG --- End Cursor:[${END_CURSOR}]"

  #############################################
  # Parse all the repo data out of data block #
  #############################################
  ParseRepoData "${DATA_BLOCK}"

  ########################################
  # See if we need to loop for more data #
  ########################################
  if [ "${NEXT_PAGE}" == "false" ]; then
    # We have all the data, we can move on
    echo "Gathered all data from GitHub"
  elif [ "${NEXT_PAGE}" == "true" ]; then
    # We need to loop through GitHub to get all repos
    echo "More pages of repos... Looping through data with new cursor:[${END_CURSOR}]"
    ######################################
    # Call GetRepos again with new cursor #
    ######################################
    GetRepos
  else
    # Failing to get this value means we didnt get a good response back from GitHub
    # And it could be bad input from user, not enough access, or a bad token
    # Fail out and have user validate the info
    echo ""
    echo "######################################################"
    echo "ERROR! Failed response back from GitHub!"
    echo "Please validate your PAT, Organization, and access levels!"
    echo "######################################################"
    exit 1
  fi
}
################################################################################
#### Function ParseRepoData ####################################################
ParseRepoData()
{
  ##########################
  # Pull in the data block #
  ##########################
  PARSE_DATA=$1

  ####################################
  # Itterate through the json object #
  ####################################
  # We are only getting the repo names
  echo "Gathering Repository information..."
  for OBJECT in $(echo "${PARSE_DATA}" | jq -r '.data.organization.repositories.nodes | .[] | .name' ); do
    #echo "RepoName:[$OBJECT]"
    TOTAL_REPO_COUNT=$((TOTAL_REPO_COUNT +1))
    ###############################
    # Push the repo names to aray #
    ###############################
    ORG_REPOS+=("${OBJECT}")
  done
}
################################################################################
#### Function GetRepoPRs #######################################################
GetRepoPRs()
{
  ##############################################
  # Loop through repos and get PRs from search #
  ##############################################
  for REPO_NAME in "${ORG_REPOS[@]}"; do
    #####################################
    # Grab all the data from the system #
    #####################################
    DATA_BLOCK=$(curl -s -X POST \
      -H "authorization: Bearer ${GITHUB_PAT}" \
      -H "content-type: application/json" \
      -d "{\"query\":\"{ search(type: ISSUE, query: \"repo:${ORG_NAME}/${REPO_NAME} label:template\", first: 5, after: null) { nodes { ... on PullRequest { number id labels(first: 100, after: null) { nodes { name } } } } pageInfo { hasNextPage endCursor } } }\"}" \
      "${GRAPHQL_URL}" 2>&1)

    #######################
    # Load the error code #
    #######################
    ERROR_CODE=$?

    ##########################
    # Check the shell return #
    ##########################
    if [ ${ERROR_CODE} -ne 0 ]; then
      echo "ERROR! Failed to gather data from GitHub!"
      exit 1
    fi

    #############################################
    # Parse all the repo data out of data block #
    #############################################
    ParsePRData "${DATA_BLOCK}" "${REPO_NAME}"
  done
}
################################################################################
#### Function ParsePRData ######################################################
ParsePRData()
{
  ##########################
  # Pull in the data block #
  ##########################
  PARSE_DATA=$1
  REPO_NAME=$2

  ###################################
  # Set to 1 if we find the open PR #
  ###################################
  FOUND_PR=0

  ####################################
  # Itterate through the json object #
  ####################################
  # We are only getting the repo names
  echo "Gathering PR information for Repository:[${REPO_NAME}]..."
  for OBJECT in $(echo "${PARSE_DATA}" | jq -r '.data.search.nodes | .[] | .number' ); do
    echo "Found Template PullRequest:[$OBJECT]"
    ###############################
    # Push the repo names to aray #
    ###############################
    FOUND_PR=1
  done

  #################################
  # Check if we had found objects #
  #################################
  if [ "${FOUND_PR}" -eq 0 ]; then
    # No template for repository
    TemplateRepo "${REPO_NAME}"
  fi
}
################################################################################
#### Function TemplateRepo #####################################################
TemplateRepo() {
  ###############################
  # Pull in the repository name #
  ###############################
  REPO_NAME=$1

  # We need to clone the repo
  # create a branch
  # push the code
  # create pull request
  # issueOps?
  CLONE_CMD=$(git clone --depth 1 https://github.com/${ORG_NAME}/${REPO_NAME} 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to clone from GitHub!"
    echo "ERROR:[${CLONE_CMD}]"
    # Run cleanup
    CleanupWorkspace "${REPO_NAME}"
    exit 1
  fi

  #########################################
  # Copy the workflow into the repository #
  #########################################
  COPY_CMD=$(mkdir "${REPO_NAME}.github/workflows" || exit 1; cp "${WORKFLOW_TEMPLATE}" "${REPO_NAME}/.github/workflows/${TEMPLATE_NAME}")

  #########################
  # Check the file exists #
  #########################
  if [ ! -f "${REPO_NAME}/.github/workflows/${TEMPLATE_NAME}" ]; then
    echo "ERROR! Failed to get file into place!"
    echo "ERROR:[COPY_CMD]"
    # Run cleanup
    CleanupWorkspace "${REPO_NAME}"
    exit 1
  fi

  ######################
  # Push Files to repo #
  ######################
  PUSH_CMD=$(
    git config --global user.name "Template Bot" 2>&1
    git config --global user.email "template@bot.com" 2>&1
    cd "${REPO_NAME}" || exit 1 2>&1
    git add . 2>&1
    git branch -b "TemplateBot" 2>&1
    git commit -m "Adding template to repository" 2>&1
    git push --set-upstream origin TemplateBot 2>&1
  )

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to push to GitHub!"
    echo "ERROR:[${PUSH_CMD}]"
    # Run cleanup
    CleanupWorkspace "${REPO_NAME}"
    exit 1
  fi

  ###############################
  # Get the default branch name #
  ###############################
  DEFAULT_BRANCH=$(cd ${REPO_NAME} || exit 1; git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  debug "DEFAULT_BRANCH:${DEFAULT_BRANCH}"

  #######################################
  # Check that we found the branch name #
  #######################################
  if [ -z "${DEFAULT_BRANCH}" ]; then
    echo "ERROR! Failed to get the default branch!"
    # Run cleanup
    CleanupWorkspace "${REPO_NAME}"
    exit 1
  fi

  ################################
  # Create The PR Body in format #
  ################################
  FormatPRBody

  ###########################
  # Create the pull request #
  ###########################
  CREATE_PR_CMD=$(curl -s --fail -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    "${GITHUB_API}/repos/${ORG_NAME}/${REPO_NAME}/pulls" \
    -d "{\"head\":\"TemplateBot\",\"base\":\"${DEFAULT_BRANCH}\", \"title\": \"TemplateBot Adding base template\", \"body\": \"${PR_BODY_STRING}\"}" 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to create PR on GitHub!"
    echo "ERROR:[${CREATE_PR_CMD}]"
    # Run cleanup
    CleanupWorkspace "${REPO_NAME}"
    exit 1
  fi

  #####################
  # Cleanup workspace #
  #####################
  CleanupWorkspace "${REPO_NAME}"
}
################################################################################
#### Function FormatPRBody #####################################################
FormatPRBody() {
  # Need to format the PR_BODY file into a string with literal \n
  PR_BODY_STRING=$(cat "${PR_BODY}" |awk '{printf "%s\\n", $0}')

  debug "PR_BODY_STRING:[${PR_BODY_STRING}]"

  ############################
  # Check if we have a value #
  ############################
  if [ -n "${PR_BODY_STRING}" ]; then
    # error
    echo "ERROR! Failed to convert template to String!"
    echo "ERROR:[${PR_BODY_STRING}]"
    exit 1
  fi
}
################################################################################
#### Function CleanupWorkspace #################################################
CleanupWorkspace()
{
  ###############################
  # Pull in the repository name #
  ###############################
  REPO_NAME=$1

  ##############################
  # Remove the local workspace #
  ##############################
  CLEAN_CMD=$(rm -rf "${REPO_NAME}" 2>&1)

  #############################
  # Check if directory exists #
  #############################
  if [ -d "${REPO_NAME}" ];
    echo "ERROR! Failed to cleanup workspace at:[${REPO_NAME}]"
    echo "ERROR:[${CLEAN_CMD}]"
    exit 1
  fi
}
################################################################################
#### Function ValidateJQ #######################################################
ValidateJQ()
{
  # Need to validate the machine has jq installed as we use it to do the parsing
  # of all the json returns from GitHub

  ############################
  # See if it is in the path #
  ############################
  CHECK_JQ=$(command -v jq)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "Failed to find jq in the path!"
    echo "ERROR:[${CHECK_JQ}]"
    echo "If this is a Mac, run command: brew install jq"
    echo "If this is Debian, run command: sudo apt install jq"
    echo "If this is Centos, run command: yum install jq"
    echo "Once installed, please run this script again."
    exit 1
  fi
}
################################################################################
#### Function DebugJQ ##########################################################
DebugJQ()
{
  # If Debug is on, print it out...
  if [[ ${DEBUG} == true ]]; then
    echo "$1" | jq '.'
  fi
}
################################################################################
#### Function Debug ############################################################
Debug()
{
  # If Debug is on, print it out...
  if [[ ${DEBUG} == true ]]; then
    echo "$1"
  fi
}
################################################################################
#### Function Footer ###########################################################
Footer()
{
  #######################################
  # Basic footer information and totals #
  #######################################
  echo ""
  echo "######################################################"
  echo "The script has completed"
  echo "Total Repos parsed:[${TOTAL_REPO_COUNT}]"
  echo "######################################################"
  echo ""
  echo ""
}
################################################################################
############################## MAIN ############################################
################################################################################

##########
# Header #
##########
Header

#########################
# Validate JQ installed #
#########################
ValidateJQ

###################
# Get GitHub Data #
###################
echo "------------------------------------------------------"
echo "Calling GitHub for Repos..."
GetRepos

######################
# Get GitHub PR Data #
######################
echo "------------------------------------------------------"
echo "Calling GitHub for PR data on Repos..."
GetRepoPRs

##########
# Footer #
##########
Footer

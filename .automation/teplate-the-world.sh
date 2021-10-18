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
PAGE_SIZE=100           # Default is 100, GitHub limit is 100
PR_END_CURSOR='null'    # Set to null, will be updated after call
END_CURSOR='null'       # Set to null, will be updated after call
TOTAL_REPO_COUNT=0      # Counter of all repos found
ORG_REPOS=()            # Array of all repos found in Org
DEBUG=''                # Set to true to enable debugging

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

#!/bin/bash
ORB_EVAL_SCHEDULE_NAME=$(eval echo "${ORB_EVAL_SCHEDULE_NAME}")
ORB_EVAL_PROJECT_NAME=$(eval echo "${ORB_EVAL_PROJECT_NAME}")
URL="https://circleci.com/api/v2/project/${ORB_VAL_VCS_TYPE}/${ORB_VAL_NAMESPACE}/${ORB_EVAL_PROJECT_NAME}/schedule"


curl -s --request GET \
  --url "${URL}" \
  --header "Circle-Token: $CIRCLE_TOKEN" > existing_schedules.json

if jq '.' -c existing_schedules.json | grep "Project not found" > /dev/null; then
  echo "The specified project is not found. Please check the project name vcs type or namespace."
  exit 1
fi




if jq ".items[] | .name" existing_schedules.json | grep "${ORB_EVAL_SCHEDULE_NAME}" > /dev/null; then
  SCHEDULE_ID=$(jq -r '.items[] | select( .name == '"\"${ORB_EVAL_SCHEDULE_NAME}\""') | .id' existing_schedules.json)
  
  set -x
  curl -s --request DELETE \
      --url https://circleci.com/api/v2/schedule/"${SCHEDULE_ID}" \
      --header "Circle-Token: ${CIRCLE_TOKEN}" > status.json
  set +x 

  jq '.' status.json
else
  echo "\"${ORB_EVAL_SCHEDULE_NAME}\" is not found. Please choose a valid schedule."
fi
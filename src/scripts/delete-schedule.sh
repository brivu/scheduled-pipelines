#!/bin/bash
ORB_EVAL_SCHEDULE_NAME=$(eval echo "${ORB_EVAL_SCHEDULE_NAME}")
ORB_EVAL_SCHEDULE_JSON_PATH=$(eval echo "${ORB_EVAL_SCHEDULE_JSON_PATH}")

curl -s --request GET \
  --url "${URL}" \
  --header "Circle-Token: $CIRCLE_TOKEN" > all_schedules.json

if jq '.' -c all_schedules.json | grep "Project not found" > /dev/null; then
  echo "The specified project is not found. Please check the project name vcs type or namespace."
  exit 1
fi

if jq ".items[] | .name" all_schedules.json | grep "${ORB_EVAL_SCHEDULE_NAME}"; then
  SCHEDULE_ID=$(jq -r '.items[] | select( .name == '"${ORB_EVAL_SCHEDULE_NAME}"') | .id' all_schedules.json)
  
  set -x
  curl -s --request DELETE \
      --url https://circleci.com/api/v2/schedule/"${SCHEDULE_ID}" \
      --header "Circle-Token: ${CIRCLE_TOKEN}" > status.json
  set +x 

  jq '.' status.json
else
  echo "\"${ORB_EVAL_SCHEDULE_NAME}\" is not found. Please choose a valid schedule."
fi
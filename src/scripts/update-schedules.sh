#!/bin/bash
ORB_EVAL_SCHEDULE_JSON_PATH=$(eval echo "${ORB_EVAL_SCHEDULE_JSON_PATH}")
UPDATED_SCHEDULES=$(jq '.schedules' -c "${ORB_EVAL_SCHEDULE_JSON_PATH}")
SCHEDULE_DATA=$(mktemp -d)
echo "export SCHEDULE_DATA=\"${SCHEDULE_DATA}\"" >> "$BASH_ENV"
if echo  "${CIRCLE_BUILD_URL}" | grep -E "GitHub|gh" > /dev/null; then
        VCS="gh"
elif echo  "${CIRCLE_BUILD_URL}" | grep -E "BitBucket|bb" > /dev/null; then
        VCS="bb"
else
        VCS="circleci"
fi

URL="https://circleci.com/api/v2/project/${VCS}/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/schedule"

next_page=$(curl -s --request GET \
  --url "${URL}" \
  --header "Circle-Token: $CIRCLE_TOKEN")

echo "${next_page}" > "${SCHEDULE_DATA}/current_schedules.json"

while [ "$(echo "$next_page" | jq -rc '.next_page_token')"  != null ];
do
        token=$(echo "$next_page" | jq -rc '.next_page_token')
        URL="https://circleci.com/api/v2/project/${VCS}/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/schedule?page-token=${token}"
        
        next_page=$(curl -s --request GET \
        --url "${URL}"   \
        --header "Circle-Token: $CIRCLE_TOKEN")

        echo "$next_page" | jq -cr '.items' | while read -r schedule
                do
                #echo "${schedule}"
                complete_list=$(jq -rc ".items[.items | length] |= .+ ${schedule}" "${SCHEDULE_DATA}/current_schedules.json")
                echo "$complete_list" | jq -r '.items' > "${SCHEDULE_DATA}/current_schedules.json"
        done

done

# curl -s --request GET \
#   --url "${URL}" \
#   --header "Circle-Token: $CIRCLE_TOKEN" > "${SCHEDULE_DATA}/current_schedules.json"

# jq '.' "${SCHEDULE_DATA}/current_schedules.json"

if jq '.' -c "${SCHEDULE_DATA}/current_schedules.json" | grep "Project not found" > /dev/null; then
  echo "The specified project is not found. Please check the project name vcs type or namespace."
  exit 1
fi

# Delete schedules 
jq -cr '.items[] | .name' "${SCHEDULE_DATA}/current_schedules.json" | while read -r current_schedule_names; 
do
    if echo "$UPDATED_SCHEDULES" |  grep -v  "${current_schedule_names}" > /dev/null; then
        SCHEDULE_ID=$(jq -r '.items[] | select( .name == '\""${current_schedule_names}"\"') | .id' "${SCHEDULE_DATA}/current_schedules.json")
            set -x
            curl -s --request DELETE \
            --url https://circleci.com/api/v2/schedule/"${SCHEDULE_ID}" \
            --header "Circle-Token: ${CIRCLE_TOKEN}" > status.json
            set +x
    fi
done


CURRENT_SCHEDULES=$(jq -cr '.items[]'  "${SCHEDULE_DATA}/current_schedules.json")
jq -c '.schedules[]' "${ORB_EVAL_SCHEDULE_JSON_PATH}" | while read -r new_schedule;
do
    new_schedule_name=$(echo "${new_schedule}" | jq -cr '.name')
    if echo "${CURRENT_SCHEDULES}" | grep "${new_schedule_name}" >/dev/null; then
        SCHEDULE_ID=$(jq -r '.items[] | select( .name == '\""${new_schedule_name}\""') | .id' "${SCHEDULE_DATA}/current_schedules.json")
        set -x
        curl -s --request PATCH \
        --url https://circleci.com/api/v2/schedule/"${SCHEDULE_ID}" \
        --header "Circle-Token: ${CIRCLE_TOKEN}" \
        --header 'content-type: application/json' \
        --data "${new_schedule}" > status.json
        set +x 
    else
        set -x
          curl -s --request POST \
              --url "${URL}" \
              --header "Circle-Token: ${CIRCLE_TOKEN}" \
              --header 'content-type: application/json' \
              --data "${new_schedule}" > status.json
          set +x
            if jq '.' -c status.json | grep "Invalid input" > /dev/null; then
              echo -e "\nPlease recheck your json schedule\n"
              jq '.message' -rc status.json
              exit 1
            fi
      fi
done

curl -s --request GET \
  --url "${URL}" \
  --header "Circle-Token: $CIRCLE_TOKEN" > "${SCHEDULE_DATA}/current_schedules.json"

jq '.' "${SCHEDULE_DATA}/current_schedules.json"

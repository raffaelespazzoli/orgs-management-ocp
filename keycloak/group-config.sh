#!/bin/bash

set -e

export admin_password=$(oc get secret credential-ocp-keycloak -n keycloak-operator -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password ${admin_password} --config /tmp/kcadm.config

#In this section we emulate org owners that connect to RH-SSO and organizes their section of the organization hierarchy by adding the dev team and application layers.
#This steps also adds the group metadata.

export retail_banking_group_id=$(oc exec -i -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get groups -r ocp --config /tmp/kcadm.config | jq '.[] | select(.name == "Retail Banking").subGroups[] | select(.name == "Online Retail Banking").id' -r)

export online_svc_team_group_id=$(oc exec -i -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${retail_banking_group_id}/children -r ocp -s name="online-svc-team" -i --config /tmp/kcadm.config)

export online_banking_login_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${online_svc_team_group_id}/children -r ocp -s name="online-banking-login-svc" -i --config /tmp/kcadm.config  -s attributes='{"type":["application"],"size":["small"]}')
export online_banking_checking_account_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${online_svc_team_group_id}/children -r ocp -s name="online-banking-checking-account-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["medium"]}')
export online_banking_investment_account_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${online_svc_team_group_id}/children -r ocp -s name="online-banking-investment-account-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["small"]}')
export online_banking_bill_payment_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${online_svc_team_group_id}/children -r ocp -s name="online-banking-bill-payment-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["large"]}')
export online_banking_money_transfer_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${online_svc_team_group_id}/children -r ocp -s name="online-banking-money-transfer-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["small"]}')

export acquisition_team_group_id=$(oc exec -i -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${retail_banking_group_id}/children -r ocp -s name="acquisition-team" -i --config /tmp/kcadm.config)

export online_acquisition_login_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${acquisition_team_group_id}/children -r ocp -s name="online-acquisition-login-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["small"]}')
export online_acquisition_kyc_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${acquisition_team_group_id}/children -r ocp -s name="online-acquisition-kyc-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["large"]}')
export online_acquisition_credit_score_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${acquisition_team_group_id}/children -r ocp -s name="online-acquisition-credit-score-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["small"]}')
export online_acquisition_fraud_detection_kyc_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${acquisition_team_group_id}/children -r ocp -s name="online-acquisition-fraud-detection-kyc-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["small"]}')


export alerts_team_group_id=$(oc exec -i -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${retail_banking_group_id}/children -r ocp -s name="alerts-team" -i --config /tmp/kcadm.config)

export online_alerts_sms_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${alerts_team_group_id}/children -r ocp -s name="online-alerts-sms-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["medium"]}')
export online_alerts_mobile_notification_svc=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create groups/${alerts_team_group_id}/children -r ocp -s name="online-alerts-mobile-notification-svc" -i --config /tmp/kcadm.config -s attributes='{"type":["application"],"size":["small"]}')




#In this section we emulate the org owners who assign users to specific groups

export dev1=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev1 --config /tmp/kcadm.config | jq -r .[0].id)
export dev2=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev2 --config /tmp/kcadm.config | jq -r .[0].id)
export dev3=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev3 --config /tmp/kcadm.config | jq -r .[0].id)
export dev4=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev4 --config /tmp/kcadm.config | jq -r .[0].id)
export dev5=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev5 --config /tmp/kcadm.config | jq -r .[0].id)
export dev6=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev6 --config /tmp/kcadm.config | jq -r .[0].id)
export dev7=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev7 --config /tmp/kcadm.config | jq -r .[0].id)
export dev8=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev8 --config /tmp/kcadm.config | jq -r .[0].id)
export dev9=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev9 --config /tmp/kcadm.config | jq -r .[0].id)
export dev10=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev10 --config /tmp/kcadm.config | jq -r .[0].id)
export dev11=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev11 --config /tmp/kcadm.config | jq -r .[0].id)
export dev12=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh get users -r ocp -q username=dev12 --config /tmp/kcadm.config | jq -r .[0].id)

oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev1}/groups/${online_banking_login_svc} -r ocp -s realm=ocp -s userId=${dev1} -s groupId=${online_banking_login_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev2}/groups/${online_banking_checking_account_svc} -r ocp -s realm=ocp -s userId=${dev2} -s groupId=${online_banking_checking_account_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev3}/groups/${online_banking_investment_account_svc} -r ocp -s realm=ocp -s userId=${dev3} -s groupId=${online_banking_investment_account_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev4}/groups/${online_banking_bill_payment_svc} -r ocp -s realm=ocp -s userId=${dev4} -s groupId=${online_banking_bill_payment_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev5}/groups/${online_banking_money_transfer_svc} -r ocp -s realm=ocp -s userId=${dev5} -s groupId=${online_banking_money_transfer_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev6}/groups/${online_acquisition_login_svc} -r ocp -s realm=ocp -s userId=${dev6} -s groupId=${online_acquisition_login_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev7}/groups/${online_acquisition_kyc_svc} -r ocp -s realm=ocp -s userId=${dev7} -s groupId=${online_acquisition_kyc_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev8}/groups/${online_acquisition_credit_score_svc} -r ocp -s realm=ocp -s userId=${dev8} -s groupId=${online_acquisition_credit_score_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev9}/groups/${online_acquisition_fraud_detection_kyc_svc} -r ocp -s realm=ocp -s userId=${dev9} -s groupId=${online_acquisition_fraud_detection_kyc_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev10}/groups/${online_alerts_sms_svc} -r ocp -s realm=ocp -s userId=${dev10} -s groupId=${online_alerts_sms_svc} -n --config /tmp/kcadm.config
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh update users/${dev11}/groups/${online_alerts_mobile_notification_svc} -r ocp -s realm=ocp -s userId=${dev11} -s groupId=${online_alerts_mobile_notification_svc} -n --config /tmp/kcadm.config
  
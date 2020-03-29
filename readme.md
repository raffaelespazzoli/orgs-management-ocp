# Organization Management Demo for OpenShift

## LDAP installation

```shell
oc new-project ldap
oc adm policy add-scc-to-user anyuid -z default -n ldap
oc apply -f ./ldap -n ldap
```

## RH-SSO Installation

```shell
oc new-project keycloak-operator
oc apply -f ./keycloak/operator.yaml -n keycloak-operator
oc apply -f ./keycloak/keycloak.yaml -n keycloak-operator
oc create route reencrypt keycloak --service keycloak
```

## RH-SSO - LDAP Integration

```shell
export admin_password=$(oc get secret credential-ocp-keycloak -n keycloak-operator -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)

oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password ${admin_password} --config /tmp/kcadm.config

export ldap_integration_id=$(oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create components --config /tmp/kcadm.config -r ocp -s name=ocp-ldap-provider -s providerId=ldap -s providerType=org.keycloak.storage.UserStorageProvider -s parentId=ocp  -s 'config.priority=["1"]' -s 'config.fullSyncPeriod=["-1"]' -s 'config.changedSyncPeriod=["-1"]' -s 'config.cachePolicy=["DEFAULT"]' -s config.evictionDay=[] -s config.evictionHour=[] -s config.evictionMinute=[] -s config.maxLifespan=[] -s 'config.batchSizeForSync=["1000"]' -s 'config.editMode=["READ_ONLY"]' -s 'config.syncRegistrations=["false"]' -s 'config.vendor=["other"]' -s 'config.usernameLDAPAttribute=["uid"]' -s 'config.rdnLDAPAttribute=["uid"]' -s 'config.uuidLDAPAttribute=["uid"]' -s 'config.userObjectClasses=["inetOrgPerson, organizationalPerson"]' -s 'config.connectionUrl=["ldap://ldap.ldap.svc:389"]'  -s 'config.usersDn=["ou=Users,dc=example,dc=com"]' -s 'config.authType=["simple"]' -s 'config.bindDn=["cn=admin,dc=example,dc=com"]' -s 'config.bindCredential=["admin"]' -s 'config.searchScope=["1"]' -s 'config.useTruststoreSpi=["ldapsOnly"]' -s 'config.connectionPooling=["true"]' -s 'config.pagination=["true"]' -s 'config.allowKerberosAuthentication=["false"]' -i)

oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create components --config /tmp/kcadm.config -r ocp -s name=ldap-groups -s providerId=group-ldap-mapper -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper -s parentId=${ldap_integration_id} -s 'config."groups.dn"=["ou=Groups,dc=example,dc=com"]' -s 'config."group.name.ldap.attribute"=["cn"]' -s 'config."group.object.classes"=["groupOfNames"]' -s 'config."preserve.group.inheritance"=["true"]' -s 'config."membership.ldap.attribute"=["member"]' -s 'config."membership.attribute.type"=["DN"]' -s 'config."groups.ldap.filter"=[]' -s 'config.mode=["READ_ONLY"]' -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' -s 'config."mapped.group.attributes"=[]' -s 'config."drop.non.existing.groups.during.sync"=["false"]' -s 'config.roles=["admins"]' -s 'config.groups=["admins-group"]' -s 'config.group=[]' -s 'config.preserve=["true"]' -s 'config.membership=["member"]' -s 'config.membership.user.ldap.attribute=["uid"]'
```

## OCP - RH-SSO integration

```shell
oc apply -f ./ocp-auth/keycloak-client.yaml -n keycloak-operator
oc apply -f ./ocp-auth/secret.yaml
export oauth_patch=$(cat ./ocp-auth/oauth.yaml | yq .)
oc patch OAuth.config.openshift.io cluster -p "${oauth_patch}" --type merge
```

# Team Onboarding Demo for OpenShift

This demo has the purpose to demonstrate how it is possible to build a fully automated end-to-end team onboarding process for OpenShift.
The main problems an onboarding process needs to take care of are the following:

1. Mapping of the corporate organization to OpenShift RBAC model. This is going to be addressed with [RH-SSO]() in this demo.
2. synchronization of groups. This is going to be addressed with the [group-sync-operator]() in this demo.
3. configuration of namespaces. This is going to be addressed with the [namespace-configuration-operator]() in this demo.

## Demo Scenario

A corporate LDAP container the org hierarchy with the following levels: LOB, BU. Informal levels that are not mapped in the corporate LDAP are dev team and application.

Scenario Requirements:

1. each application needs to be provisioned with 4 SDLC environments with the following naming convention: <app>-build, <app>-dev, <app>-qa, <app>-prod
2. every one in the dev team should have `view` access to the all the environments of all the applications in that dev team
3. every one on specifically assigned to an app should have `edit` access to the SDLC environments of that app.
4. the build environment is the only one where builds can run.
5. builds need to talk only to the corporate nexus (nexus.mycorp.com) and to the corporate gitlab (gitlab.mycorp.com). Any other communication must be stopped.
6. the dev and qa environments can establish connections with the internal corporate networks (10.11.0.0) and the corporate nexus for image pulling.
7. the prod environment can only talk to the prod network (10.12.0.0) and the pci network (10.13.0.0) and the corporate nexus for image pulling.
8. each project will receive a default network policy configuration, by which pods are allowed to communicate only within the namespace and receive connections from the router pods. Owner of those namespaces are allowed to add more network policy rules.
9. the -build projects will receive very limited quotas.
10. the -dev and -qa projects will share a multiproject quota that the developer can allocate based on their needs. The multiproject quota can be chosen at project creation among three T-shirt sizes.
11. the -prod project will receive its own quota, again the quota will be chosen at project creation.
12. dev, qa and prod project will be assigned egress IPs (we assume the [egressip-ipam-operator](https://github.com/redhat-cop/egressip-ipam-operator) is installed).


## LDAP installation

```shell
oc new-project ldap
oc adm policy add-scc-to-user anyuid -z default -n ldap
oc apply -f ./ldap -n ldap
```

After this step you should be able to connect to the ldap admin UI:

```shell
echo https://$(oc get route ldap-admin -n ldap -o jsonpath='{.spec.host}')
```

with "cn=admin,dc=example,dc=com"/admin credentials.

If data has been loaded correclty you should see this situation:

![LDAP Groups](/media/ldap-setup.png)

This represents the situation we might find in a enterprise LDAP and is the starting point of our demo.

## RH-SSO Installation

```shell
oc new-project keycloak-operator
oc apply -f ./keycloak/operator.yaml -n keycloak-operator
oc apply -f ./keycloak/keycloak.yaml -n keycloak-operator
oc create route reencrypt keycloak --port 8443 --service keycloak -n keycloak-operator
```

## RH-SSO - LDAP Integration

```shell
export admin_password=$(oc get secret credential-ocp-keycloak -n keycloak-operator -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
oc exec -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password ${admin_password} --config /tmp/kcadm.config
export ldap_integration_id=$(cat ./keycloak/ldap-federation.json | envsubst | oc exec -i -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create components --config /tmp/kcadm.config -r ocp -f - -i)
echo created ldap integration $ldap_integration_id
cat ./keycloak/role-mapper.json | envsubst | oc exec -i -n keycloak-operator keycloak-0 -- /opt/jboss/keycloak/bin/kcadm.sh create components --config /tmp/kcadm.config -r ocp -f -
```

After this step, if you should be able to login RH-SSO

```shell
echo https://$(oc get route keycloak -n keycloak-operator -o jsonpath='{.spec.host}')
echo admin/${admin_password}
```

and you should see the following groups

![LDAP Groups](/media/ldap-groups.png)

It may take about 5 minutes for the groups to fully synchronize.


## RH-SSO Group Augmentation

In this section we emulate org owners that connect to RH-SSO and organizes their portion of the organization hierarchy by adding the dev team and application layers.

```shell
./keycloak/group-config.sh
```

this command will take a while. After executing it, you should see the following:

![Augmented Groups](/media/augmented-groups.png)

## OCP - RH-SSO integration

```shell
export keycloak_route=$(oc get route keycloak -n keycloak-operator -o jsonpath='{.spec.host}')
export auth_callback=$(oc get route oauth-openshift -n openshift-authentication -o jsonpath='{.spec.host}')/oauth2callback
cat ./ocp-auth/keycloak-client.yaml | envsubst | oc apply -f - -n keycloak-operator
oc apply -f ./ocp-auth/secret.yaml
oc get secrets -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc -n openshift-config create configmap ocp-ca-bundle --from-file=/tmp/ca.crt
export oauth_patch=$(cat ./ocp-auth/oauth.yaml | envsubst | yq .)
oc patch OAuth.config.openshift.io cluster -p '[{"op": "add", "path": "/spec/identityProviders/-", "value": '"${oauth_patch}"' }]' --type json
```

## OCP - RH-SSO Group Sync

### Deploy the group sync operator

```shell
oc new-project group-sync-operator
oc apply -f ./group-sync/operator.yaml -n group-sync-operator
```

### Deploy group sync logic

```shell
export keycloak_route=$(oc get route keycloak -n keycloak-operator -o jsonpath='{.spec.host}')
export admin_password=$(oc get secret credential-ocp-keycloak -n keycloak-operator -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
oc create secret generic keycloak-group-sync --from-literal=username=admin --from-literal=password=${admin_password} -n keycloak-operator
cat ./group-sync/groupsync.yaml | envsubst | oc apply -f -
```

## Deploy the namespace configurations

### Deploy namespace-configuration-operator

```shell
oc new-project namespace-configuration-operator
oc apply -f ./namespace-configuration/operator.yaml -n namespace-configuration-operator
```

## Deploy namespace configuration

```shell
oc apply -f ./namespace-configuration/admin-no-build-role.yaml
oc apply -f ./namespace-configuration/app-namespace-groupconfig.yaml
oc apply -f ./namespace-configuration/multiproject-quota-groupconfig.yaml
oc apply -f ./namespace-configuration/role-binding-groupconfig.yaml
oc apply -f ./namespace-configuration/egress-networkpolicy-namespaceconfig.yaml
oc apply -f ./namespace-configuration/networkpolicy-namespaceconfig.yaml
oc apply -f ./namespace-configuration/quota-namespaceconfig.yaml
```

## Extras

### RH-ServiceMesh - RH-SSO integration

Assuming you deployed istio in `istio-system` and bookinfo in `bookinfo`, this will create an OIDC authetication rule for the mesh.
here are the [instructions](https://github.com/raffaelespazzoli/openshift-enablement-exam/tree/master/misc4.0/ServiceMesh).

```shell
export keycloak_route=$(oc get route keycloak -n keycloak-operator -o jsonpath='{.spec.host}')
cat ./istio/mesh-control-plane.yaml | envsubst | oc apply -f - -n istio-system
oc create route reencrypt oauth-ingressgateway --service oauth-ingressgateway --port 8444 -n istio-system
export oauth_ingress=$(oc get route oauth-ingressgateway -n istio-system -o jsonpath='{.spec.host}')
cat ./istio/keycloak-client.yaml | envsubst | oc apply -f - -n keycloak-operator
# this does not work, see: https://github.com/istio/istio/issues/22733
cat ./istio/policy.yaml | envsubst | oc apply -f - -n bookinfo
echo https://$oauth_ingress/productpage
```

point your browser to the last URL printed in the last line.

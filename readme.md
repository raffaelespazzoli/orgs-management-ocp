# Organization Management Demo for OpenShift

## LDAP installation

```shell
oc new-project ldap
oc adm policy add-scc-to-user anyuid -z default -n ldap
oc apply -f ./ldap -n ldap
```

## RH-SSO Installation

```shell
oc new project keycloak-operator
oc apply -f ./keycloak/operator.yaml -n keycloak-operator
oc apply -f./keycloak/keycloak.yaml -n keycloak-operator
```

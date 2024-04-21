# Guided Exercise: Define and Apply Permissions with RBAC

Define role-based access controls and apply permissions to users.

## Outcomes

*   Remove project creation privileges from users who are not OpenShift cluster administrators.
*   Create OpenShift groups and add members to these groups.
*   Create a project and assign project administration privileges to the project.
*   As a project administrator, assign read and write privileges to different groups of users.

## Instructions

1.  Log in to the OpenShift cluster and determine which cluster role bindings assign the `self-provisioner` cluster role.

    1. Run the login command in your terminal, with the login provided to you (requires admin access):
    
        ```sh
        export OCP_USER=team1 # CHANGEME
        export OCP_PASSWORD=123 # CHANGEME
        export OCP_SERVER=https://api.example.com:6443 # CHANGEME
        oc login -u ${OCP_USER} -p ${OCP_PASSWORD} --server=${OCP_SERVER}
        ```
        
    2.  List all cluster role bindings that reference the `self-provisioner` cluster role.
    
        ```sh
        oc get clusterrolebinding -o wide | grep -E 'ROLE|self-provisioner'
        ```
        
2.  Remove the privilege to create projects from all users who are not cluster administrators by deleting the `self-provisioner` cluster role from the `system:authenticated:oauth` virtual group.
    
    1.  Confirm that the `self-provisioners` cluster role binding that you found in the previous step assigns the `self-provisioner` cluster role to the `system:authenticated:oauth` group.
        
    
        ```sh
        oc describe clusterrolebindings self-provisioners
        ```
        
        Expected output:
        ```
        Name:         self-provisioners
        Labels:       <none>
        Annotations:  rbac.authorization.kubernetes.io/autoupdate: true
        Role:
          Kind:  ClusterRole
          Name:  self-provisioner
        Subjects:
          Kind   Name                        Namespace
          ----   ----                        ---------
          Group  system:authenticated:oauth
        ```
        
    2.  Remove the `self-provisioner` cluster role from the `system:authenticated:oauth` virtual group, which deletes the `self-provisioners` role binding.
        
    
        ```sh
        oc adm policy remove-cluster-role-from-group self-provisioner system:authenticated:oauth
        ```
        
        Expected output:
        ```
        Warning: Your changes may get lost whenever a master is restarted, unless you prevent reconciliation of this rolebinding using the following command:
        oc annotate clusterrolebinding.rbac self-provisioners 'rbac.authorization.kubernetes.io/autoupdate=false' --overwrite
        clusterrole.rbac.authorization.k8s.io/self-provisioner removed: "system:authenticated:oauth"
        ```

        !!! note
            You can safely ignore the warning about your changes being lost.
        
    3.  Verify that the role is removed from the group. The cluster role binding `self-provisioners` should not exist.
        
        ```sh
        oc describe clusterrolebindings self-provisioners
        ```
        
        Expected output:
        ```
        Error from server (NotFound): clusterrolebindings.rbac.authorization.k8s.io "self-provisioners" not found
        ```

    4.  Determine whether any other cluster role bindings reference the `self-provisioner` cluster role.
        
        ```sh
        oc get clusterrolebinding -o wide | grep -E 'ROLE|self-provisioner'
        ```
        
        Expected output:
        ```
        NAME      ROLE      AGE      USERS      GROUPS      SERVICEACCOUNTS
        ```
        
    5.  Log in as the `leader-${SUFFIX}` user with the `redhat` password.
        
        ```sh
        export SUFFIX=${OCP_USER} # e.g. team1
        oc login -u leader-${SUFFIX} -p redhat
        ```
        
        Expected output:
        ```
        Login successful.
        ...output omitted...
        ```
        
    6.  Try to create a project. The operation should fail.

        ```sh
        oc new-project test
        ```
        
        Expected output:
        ```
        Error from server (Forbidden): You may not request a new project via this API.
        ```
        
3.  Create a project and add project administration privileges to the `leader-${SUFFIX}` user.
    
    1.  Log in with your admin user:

        ```sh
        oc login -u ${OCP_USER} -p ${OCP_PASSWORD}
        ```
        
        Expected output:
        ```
        Login successful.
        ...output omitted...
        ```
        
    2.  Create the `auth-rbac-${SUFFIX}` project.

        ```sh
        oc new-project auth-rbac-${SUFFIX}
        ```
        
        Expected output:
        ```
        Now using project "auth-rbac-${SUFFIX}" on server "https://api.ocp4.example.com:6443".
        ...output omitted...
        ```
        
    3.  Grant project administration privileges to the `leader-${SUFFIX}` user on the `auth-rbac-${SUFFIX}` project.

        ```sh
        oc policy add-role-to-user admin leader-${SUFFIX}
        ```
        
        Expected output:
        ```
        clusterrole.rbac.authorization.k8s.io/admin added: "leader-${SUFFIX}"
        ```
        
4.  Create the `dev-group-${SUFFIX}` and `qa-group-${SUFFIX}` groups and add their respective members.
    
    1.  Create a group named `dev-group-${SUFFIX}`.

        ```sh
        oc adm groups new dev-group-${SUFFIX}
        ```
        
        Expected output:
        ```
        group.user.openshift.io/dev-group-${SUFFIX} created
        ```
        
    2.  Add the `developer-${SUFFIX}` user to the group that you created in the previous step.

        ```sh
        oc adm groups add-users dev-group-${SUFFIX} developer-${SUFFIX}
        ```
        
        Expected output:
        ```
        group.user.openshift.io/dev-group-${SUFFIX} added: "developer-${SUFFIX}"
        ```
        
    3.  Create a second group named `qa-group-${SUFFIX}`.

        ```sh
        oc adm groups new qa-group-${SUFFIX}
        ```
        
        Expected output:
        ```
        group.user.openshift.io/qa-group-${SUFFIX} created
        ```
        
    4.  Add the `qa-engineer-${SUFFIX}` user to the group that you created in the previous step.

        ```sh
        oc adm groups add-users qa-group-${SUFFIX} qa-engineer-${SUFFIX}
        ```
        
        Expected output:
        ```
        group.user.openshift.io/qa-group-${SUFFIX} added: "qa-engineer-${SUFFIX}"
        ```
        
    5.  Review all existing OpenShift groups to verify that they have the correct members.

        ```sh
        oc get groups
        ```
        
5.  As the `leader-${SUFFIX}` user, assign write privileges for `dev-group-${SUFFIX}` and read privileges for `qa-group-${SUFFIX}` to the `auth-rbac-${SUFFIX}` project.
    
    1.  Log in as the `leader-${SUFFIX}` user.

        ```sh
        oc login -u leader-${SUFFIX} -p redhat
        ```
        
        Expected output:
        ```
        Login successful.
        
        ...output omitted...
        
        Using project "auth-rbac-${SUFFIX}".
        ```
        
    2.  Add write privileges to the `dev-group-${SUFFIX}` group on the `auth-rbac-${SUFFIX}` project.

        ```sh
        oc policy add-role-to-group edit dev-group-${SUFFIX}
        ```
        
        Expected output:
        ```
        clusterrole.rbac.authorization.k8s.io/edit added: "dev-group-${SUFFIX}"
        ```

    3.  Add read privileges to the `qa-group-${SUFFIX}` group on the `auth-rbac-${SUFFIX}` project.

        ```sh
        oc policy add-role-to-group view qa-group-${SUFFIX}
        ```
        
        Expected output:
        ```
        clusterrole.rbac.authorization.k8s.io/view added: "qa-group-${SUFFIX}"
        ```
        
    4.  Review all role bindings on the `auth-rbac-${SUFFIX}` project to verify that they assign roles to the correct groups and users. The following output omits default role bindings that OpenShift assigns to service accounts.

        ```sh
        oc get rolebindings -o wide | grep -v '^system:'
        ```
        
6.  As the `developer-${SUFFIX}` user, deploy an Apache HTTP Server to prove that the `developer-${SUFFIX}` user has write privileges in the project. Also try to grant write privileges to the `qa-engineer-${SUFFIX}` user to prove that the `developer-${SUFFIX}` user has no project administration privileges.
    
    1.  Log in as the `developer-${SUFFIX}` user.

        ```sh
        oc login -u developer-${SUFFIX} -p redhat
        ```
        
        Expected output:
        ```
        
        Login successful.
        
        ...output omitted...
        
        Using project "auth-rbac-${SUFFIX}".
        ```
        
    2.  Deploy an Apache HTTP Server by using the standard image stream from OpenShift.

        ```sh
        oc new-app --name httpd httpd:2.4
        ```
        
        Expected output:
        ```
        _...output omitted..._
        --> Creating resources ...
            imagestreamtag.image.openshift.io "httpd:2.4" created
        Warning: would violate PodSecurity "restricted:v1.24": _...output omitted..._
            deployment.apps "httpd" created
            service "httpd" created
        --> Success
        _...output omitted..._
        ```

        !!! note
            It is safe to ignore pod security warnings for exercises in this course. OpenShift uses the Security Context Constraints controller to provide safe defaults for pod security.
        
    3.  Try to grant write privileges to the `qa-engineer-${SUFFIX}` user. The operation should fail.

        ```sh
        oc policy add-role-to-user edit qa-engineer-${SUFFIX}
        ```
        
        Expected output:
        ```
        Error from server (Forbidden): rolebindings.rbac.authorization.k8s.io is forbidden: User "developer-${SUFFIX}" cannot list resource "rolebindings" in API group "rbac.authorization.k8s.io" in the namespace "auth-rbac-${SUFFIX}"
        ```        
        
7.  Verify that the `qa-engineer-${SUFFIX}` user can view objects in the `auth-rbac-${SUFFIX}` project, but not modify anything.
    
    1.  Log in as the `qa-engineer-${SUFFIX}` user.

        ```sh
        oc login -u qa-engineer-${SUFFIX} -p redhat
        ```
        
        Expected output:
        ```
        Login successful.
        
        _...output omitted..._
        
        Using project "auth-rbac-${SUFFIX}".
        ```
        
    2.  Attempt to scale the `httpd` application. The operation should fail.

        ```sh
        oc scale deployment httpd --replicas 3
        ```
        
        Expected output:
        ```
        Error from server (Forbidden): deployments.apps "httpd" is forbidden: User "qa-engineer-${SUFFIX}" cannot patch resource "deployments/scale" in API group "apps" in the namespace "auth-rbac-${SUFFIX}"
        ```
        
8.  Restore project creation privileges to all users.
    
    1.  Log in with your admin user:

        ```sh
        oc login -u ${OCP_USER} -p ${OCP_PASSWORD}
        ```
        
    2.  Restore project creation privileges for all users by re-creating the `self-provisioners` cluster role binding that the OpenShift installer created.

        ```sh
        oc adm policy add-cluster-role-to-group --rolebinding-name self-provisioners self-provisioner system:authenticated:oauth
        ```
        
        Expected output:
        ```
        Warning: Group 'system:authenticated:oauth' not found
        clusterrole.rbac.authorization.k8s.io/self-provisioner added: "system:authenticated:oauth"
        ```

        !!! note
            You can safely ignore the warning that the group was not found.
        
Congrats, you have completed the lab!

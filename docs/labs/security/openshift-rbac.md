## Guided Exercise: Define and Apply Permissions with RBAC

Define role-based access controls and apply permissions to users.

**Outcomes**

*   Remove project creation privileges from users who are not OpenShift cluster administrators.
    
*   Create OpenShift groups and add members to these groups.
    
*   Create a project and assign project administration privileges to the project.
    
*   As a project administrator, assign read and write privileges to different groups of users.
    

As the `student` user on the `workstation` machine, use the `lab` command to prepare your system for this exercise.

This command ensures that the cluster API is reachable and creates some HTPasswd users for the exercise.

\[student@workstation ~\]$ **`lab start auth-rbac`**

**Instructions**

1.  Log in to the OpenShift cluster and determine which cluster role bindings assign the `self-provisioner` cluster role.
    
    1.  Log in to the cluster as the `admin` user.
        
        \[student@workstation ~\]$ **`oc login -u admin -p redhatocp \   https://api.ocp4.example.com:6443`**
        Login successful.
        
        _...output omitted..._
        
    2.  List all cluster role bindings that reference the `self-provisioner` cluster role.
        
        \[student@workstation ~\]$ **`oc get clusterrolebinding -o wide | \   grep -E 'ROLE|self-provisioner'`**
        NAME              ROLE                         ... GROUPS                     ...
        self-provisioners `ClusterRole/self-provisioner` ... `system:authenticated:oauth`
        
2.  Remove the privilege to create projects from all users who are not cluster administrators by deleting the `self-provisioner` cluster role from the `system:authenticated:oauth` virtual group.
    
    1.  Confirm that the `self-provisioners` cluster role binding that you found in the previous step assigns the `self-provisioner` cluster role to the `system:authenticated:oauth` group.
        
        \[student@workstation ~\]$ **`oc describe clusterrolebindings self-provisioners`**
        Name:         self-provisioners
        Labels:       <none>
        Annotations:  rbac.authorization.kubernetes.io/autoupdate: true
        Role:
          Kind:  `ClusterRole`
          Name:  `self-provisioner`
        Subjects:
          Kind   Name                        Namespace
          ----   ----                        ---------
          Group  `system:authenticated:oauth`
        
    2.  Remove the `self-provisioner` cluster role from the `system:authenticated:oauth` virtual group, which deletes the `self-provisioners` role binding.
        
        \[student@workstation ~\]$ **`oc adm policy remove-cluster-role-from-group \   self-provisioner system:authenticated:oauth`**
        Warning: Your changes may get lost whenever a master is restarted, unless you prevent reconciliation of this rolebinding using the following command:
        oc annotate clusterrolebinding.rbac self-provisioners 'rbac.authorization.kubernetes.io/autoupdate=false' --overwrite
        clusterrole.rbac.authorization.k8s.io/self-provisioner removed: "system:authenticated:oauth"
        
        ### Note
        
        You can safely ignore the warning about your changes being lost.
        
    3.  Verify that the role is removed from the group. The cluster role binding `self-provisioners` should not exist.
        
        \[student@workstation ~\]$ **`oc describe clusterrolebindings self-provisioners`**
        Error from server (NotFound): clusterrolebindings.rbac.authorization.k8s.io "self-provisioners" not found
        
    4.  Determine whether any other cluster role bindings reference the `self-provisioner` cluster role.
        
        \[student@workstation ~\]$ **`oc get clusterrolebinding -o wide | \   grep -E 'ROLE|self-provisioner'`**
        NAME      ROLE      AGE      USERS      GROUPS      SERVICEACCOUNTS
        
    5.  Log in as the `leader` user with the `redhat` password.
        
        \[student@workstation ~\]$ **`oc login -u leader -p redhat`**
        Login successful.
        
        _...output omitted..._
        
    6.  Try to create a project. The operation should fail.
        
        \[student@workstation ~\]$ **`oc new-project test`**
        Error from server (Forbidden): You may not request a new project via this API.
        
3.  Create a project and add project administration privileges to the `leader` user.
    
    1.  Log in as the `admin` user.
        
        \[student@workstation ~\]$ **`oc login -u admin -p redhatocp`**
        Login successful.
        
        _...output omitted..._
        
    2.  Create the `auth-rbac` project.
        
        \[student@workstation ~\]$ **`oc new-project auth-rbac`**
        Now using project "auth-rbac" on server "https://api.ocp4.example.com:6443".
        
        _...output omitted..._
        
    3.  Grant project administration privileges to the `leader` user on the `auth-rbac` project.
        
        \[student@workstation ~\]$ **`oc policy add-role-to-user admin leader`**
        clusterrole.rbac.authorization.k8s.io/admin added: "leader"
        
4.  Create the `dev-group` and `qa-group` groups and add their respective members.
    
    1.  Create a group named `dev-group`.
        
        \[student@workstation ~\]$ **`oc adm groups new dev-group`**
        group.user.openshift.io/dev-group created
        
    2.  Add the `developer` user to the group that you created in the previous step.
        
        \[student@workstation ~\]$ **`oc adm groups add-users dev-group developer`**
        group.user.openshift.io/dev-group added: "developer"
        
    3.  Create a second group named `qa-group`.
        
        \[student@workstation ~\]$ **`oc adm groups new qa-group`**
        group.user.openshift.io/qa-group created
        
    4.  Add the `qa-engineer` user to the group that you created in the previous step.
        
        \[student@workstation ~\]$ **`oc adm groups add-users qa-group qa-engineer`**
        group.user.openshift.io/qa-group added: "qa-engineer"
        
    5.  Review all existing OpenShift groups to verify that they have the correct members.
        
        \[student@workstation ~\]$ **`oc get groups`**
        NAME                USERS
        Default SMB Group
        admins              Administrator
        `dev-group           developer`
        developer
        editors
        ocpadmins           Administrator
        ocpdevs             . developer
        `qa-group            qa-engineer`
        
        ### Note
        
        The lab environment already contains groups from the lab LDAP directory.
        
5.  As the `leader` user, assign write privileges for `dev-group` and read privileges for `qa-group` to the `auth-rbac` project.
    
    1.  Log in as the `leader` user.
        
        \[student@workstation ~\]$ **`oc login -u leader -p redhat`**
        Login successful.
        
        _...output omitted..._
        
        Using project "auth-rbac".
        
    2.  Add write privileges to the `dev-group` group on the `auth-rbac` project.
        
        \[student@workstation ~\]$ **`oc policy add-role-to-group edit dev-group`**
        clusterrole.rbac.authorization.k8s.io/edit added: "dev-group"
        
    3.  Add read privileges to the `qa-group` group on the `auth-rbac` project.
        
        \[student@workstation ~\]$ **`oc policy add-role-to-group view qa-group`**
        clusterrole.rbac.authorization.k8s.io/view added: "qa-group"
        
    4.  Review all role bindings on the `auth-rbac` project to verify that they assign roles to the correct groups and users. The following output omits default role bindings that OpenShift assigns to service accounts.
        
        \[student@workstation ~\]$ **`oc get rolebindings -o wide | grep -v '^system:'`**
        NAME      ROLE                AGE    USERS    GROUPS      SERVICEACCOUNTS
        admin     ClusterRole/admin   60s    admin
        admin-0   ClusterRole/admin   45s    leader
        edit      ClusterRole/edit    30s             dev-group
        view      ClusterRole/view    15s             qa-group
        
6.  As the `developer` user, deploy an Apache HTTP Server to prove that the `developer` user has write privileges in the project. Also try to grant write privileges to the `qa-engineer` user to prove that the `developer` user has no project administration privileges.
    
    1.  Log in as the `developer` user.
        
        \[student@workstation ~\]$ **`oc login -u developer -p developer`**
        Login successful.
        
        _...output omitted..._
        
        Using project "auth-rbac".
        
    2.  Deploy an Apache HTTP Server by using the standard image stream from OpenShift.
        
        \[student@workstation ~\]$ **`oc new-app --name httpd httpd:2.4`**
        _...output omitted..._
        --> Creating resources ...
            imagestreamtag.image.openshift.io "httpd:2.4" created
        Warning: would violate PodSecurity "restricted:v1.24": _...output omitted..._
            deployment.apps "httpd" created
            service "httpd" created
        --> Success
        _...output omitted..._
        
        ### Note
        
        It is safe to ignore pod security warnings for exercises in this course. OpenShift uses the Security Context Constraints controller to provide safe defaults for pod security.
        
    3.  Try to grant write privileges to the `qa-engineer` user. The operation should fail.
        
        \[student@workstation ~\]$ **`oc policy add-role-to-user edit qa-engineer`**
        Error from server (Forbidden): rolebindings.rbac.authorization.k8s.io is forbidden: User "developer" cannot list resource "rolebindings" in API group "rbac.authorization.k8s.io" in the namespace "auth-rbac"
        
7.  Verify that the `qa-engineer` user can view objects in the `auth-rbac` project, but not modify anything.
    
    1.  Log in as the `qa-engineer` user.
        
        \[student@workstation ~\]$ **`oc login -u qa-engineer -p redhat`**
        Login successful.
        
        _...output omitted..._
        
        Using project "auth-rbac".
        
    2.  Attempt to scale the `httpd` application. The operation should fail.
        
        \[student@workstation ~\]$ **`oc scale deployment httpd --replicas 3`**
        Error from server (Forbidden): deployments.apps "httpd" is forbidden: User "qa-engineer" cannot patch resource "deployments/scale" in API group "apps" in the namespace "auth-rbac"
        
8.  Restore project creation privileges to all users.
    
    1.  Log in as the `admin` user.
        
        \[student@workstation ~\]$ **`oc login -u admin -p redhatocp`**
        Login successful.
        
        _...output omitted..._
        
    2.  Restore project creation privileges for all users by re-creating the `self-provisioners` cluster role binding that the OpenShift installer created.
        
        \[student@workstation ~\]$ **`oc adm policy add-cluster-role-to-group \   --rolebinding-name self-provisioners \   self-provisioner system:authenticated:oauth`**
        Warning: Group 'system:authenticated:oauth' not found
        clusterrole.rbac.authorization.k8s.io/self-provisioner added: "system:authenticated:oauth"
        
        ### Note
        
        You can safely ignore the warning that the group was not found.
        

**Finish**

On the `workstation` machine, use the `lab` command to complete this exercise. This step is important to ensure that resources from previous exercises do not impact upcoming exercises.

\[student@workstation ~\]$ **`lab finish auth-rbac`**

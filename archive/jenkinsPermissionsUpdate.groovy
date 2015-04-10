import jenkins.*
import jenkins.model.*
import hudson.*
import hudson.model.*
import groovy.json.JsonSlurper
import groovy.io.FileType
import net.sf.json.JSONObject
import com.michelin.cio.hudson.plugins.rolestrategy.*
import hudson.security.*
stratClass = hudson.model.Hudson.getInstance().getDescriptorByType(com.michelin.cio.hudson.plugins.rolestrategy.RoleBasedAuthorizationStrategy.DescriptorImpl.class) 
authStrat = Hudson.getInstance().getAuthorizationStrategy()

def debug = System.getenv()['DEBUG'] ?: false
def userJsonList = []
def nameList = []
def dataBagPath =  System.getenv()['DATABAGPATH'] ?: "/tmp/vagrant-chef-1/data_bags_path_1/data_bags" // /var/lib/jenkins/workspace/data-bag-zdconfig-projects/chef/data_bags/

//local jenkins deploy check
def temp = new File(dataBagPath)
if (!temp.exists())
	dataBagPath = "/etc/chef/chef-solo-3/data_bags/"
temp = new File(dataBagPath)
assert temp.exists()

def dirName = new File(dataBagPath + "users/")
assert dirName.exists()
dirName.eachFileRecurse (FileType.FILES) { file ->
	if (file.name != ".DS_Store")
		userJsonList << file
}

//gather all users and map their crowd names
def crowdUserMap = [:]
userJsonList.each {
	def inputFile = new File(it.path)
	JSONObject InputJSONuser = new JsonSlurper().parseText(inputFile.text)
	if (InputJSONuser.get("active")){
		nameList << InputJSONuser.get("crowd_id")
		crowdUserMap.put(InputJSONuser.get("id"), InputJSONuser.get("crowd_id"))
	}
}

//if there are no user bags, abort before destroying all users
assert nameList != null && nameList.size() != 0

Map < String, JSONObject > maps = authStrat.getRoleMaps()
roleMap = authStrat.getRoleMap()

//clear global level users
roleClear = maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRoles()
roleClear.each(){
	authStrat.getRoleMap(RoleBasedAuthorizationStrategy.GLOBAL).clearSidsForRole(it) 
}

//gather permission objects for global roles
def globalAdminPermissionSet = [] as Set
def globalProjectAdminPermissionSet = [] as Set
def globalProjectAdminPermissons = [["class hudson.model.Hudson", "Read"], ["interface hudson.model.Item", "Configure"], 
	["interface hudson.model.Item", "Build"], ["class hudson.model.View", "Read"]]
def globalProjectUserPermissionSet = [] as Set
def globalProjectUserPermissons = [["class hudson.model.Hudson", "Read"]]
stratClass.getGroups(RoleBasedAuthorizationStrategy.GLOBAL).each(){ permission ->
	permission.each(){
		if (it != null)
			globalAdminPermissionSet.add(it)
	}
	globalProjectAdminPermissons.each(){
		if (permission.find(it[1]) != null && permission.find(it[1]).owner.toString().equals(it[0]))
			globalProjectAdminPermissionSet.add(permission.find(it[1]))
	}
	globalProjectUserPermissons.each(){
		if (permission.find(it[1]) != null && permission.find(it[1]).owner.toString().equals(it[0]))
			globalProjectUserPermissionSet.add(permission.find(it[1]))
	}
}

//make global roles 
Role globalAdminRole = new Role("admin", globalAdminPermissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.GLOBAL, globalAdminRole)
Role globalProjectAdminRole = new Role("Project Admin", globalProjectAdminPermissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.GLOBAL, globalProjectAdminRole)
Role globalProjectUserRole = new Role("Project User", globalProjectUserPermissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.GLOBAL, globalProjectUserRole)

//assign full rights to user automation and admin for default
["admin", "Project Admin", "Project User"].each(){ permission ->
  	["automation","admin"].each(){ user ->
  		if (debug)
  			println RoleBasedAuthorizationStrategy.GLOBAL + "   " + maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRole(permission).getName() + "   " + user
		authStrat.assignRole(RoleBasedAuthorizationStrategy.GLOBAL, maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRole(permission), user) 
    }
}

def slavePermissionSet = [] as Set
def slavePermissons = ["Configure", "Delete", "Disconnect", "Connect", "Build"]
//gather permission objects for slave
stratClass.getGroups(RoleBasedAuthorizationStrategy.SLAVE).each(){ permission ->
	slavePermissons.each(){
		if (permission.find(it) != null)
			slavePermissionSet.add(permission.find(it))
	}
}

//add slave admin role
Role slaveRole = new Role("slaveAdmin", ".*", slavePermissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.SLAVE, slaveRole)

["automation","admin"].each(){ user ->
  		if (debug)
  			println RoleBasedAuthorizationStrategy.SLAVE + "   " + maps.get(RoleBasedAuthorizationStrategy.SLAVE).getRole("slaveAdmin").getName() + "   " + user
		authStrat.assignRole(RoleBasedAuthorizationStrategy.SLAVE, maps.get(RoleBasedAuthorizationStrategy.SLAVE).getRole("slaveAdmin"), user) 
}

//assign all users to project user role on global
nameList.each(){
	if (debug)
		println RoleBasedAuthorizationStrategy.GLOBAL + "   " + maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRole("Project User").getName() + "   " + it
	authStrat.assignRole(RoleBasedAuthorizationStrategy.GLOBAL, maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRole("Project User"), it)     
}

def projectJsonList = []
def dirProject = new File(dataBagPath + "projects/")
assert dirProject.exists()
dirProject.eachFileRecurse (FileType.FILES) { files ->
	if (files.name != ".DS_Store")
		projectJsonList << files
}

//make sure there is at least one project
assert projectJsonList != null && projectJsonList.size() != 0

//clear project level users
roleClear = maps.get(RoleBasedAuthorizationStrategy.PROJECT).getRoles()
roleClear.each(){
	authStrat.getRoleMap(RoleBasedAuthorizationStrategy.PROJECT).clearSidsForRole(it) 
}

def permissionSet = [] as Set
def jobPermissons = ["Read", "Build", "Update", "Tag"]
//gather permission objects
stratClass.getGroups(RoleBasedAuthorizationStrategy.PROJECT).each(){ permission ->
	jobPermissons.each(){
		if (permission.find(it) != null)
			permissionSet.add(permission.find(it))
	}
}

//catch-all for old/unused unique job names, added to shared view
def misJobs = "(?i)shared.*|(?i)slave.*|(?i)master.*(?i)roxy.*(?i)radiology.*|(?i)ec2.*|(?i)yum.*|(?i)system.*|(?i)patient.*|(?i)order.*|\
  (?i)notes.*|(?i)consults.*|(?i)admin.*|(?i)discharge.*|(?i)immune.*|(?i)lab.*|(?i)add.*|(?i)medication.*|(?i)demo.*|(?i)document.*|(?i)data.*"
Role sharedRole = new Role("shared", misJobs, permissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.PROJECT, sharedRole)

//enterprise cookbook repo name mismatch to jobs and ehmp to not include ehmp-ui jobs
Role enterpriseRole = new Role("enterprise_cookbooks", "(?i)enterprise_cookbook.*", permissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.PROJECT, enterpriseRole)
Role ehmpRole = new Role("ehmp", "(?i)ehmp(?!-ui).*", permissionSet) 
authStrat.addRole(RoleBasedAuthorizationStrategy.PROJECT, ehmpRole)

//add users and admin to project roles. Also add project admins to global role
projectJsonList.each {
	def inputFile = new File(it.path)
	JSONObject InputJSONrepo = new JsonSlurper().parseText(inputFile.text)
	repoIds = InputJSONrepo.get("git_repos").getAt("id")
    repoIds.each(){ key ->
  		repoUsers = InputJSONrepo.get("users")
  		InputJSONrepo.get("admins").each(){ 
  			if (crowdUserMap.get(it) != null){
  				repoUsers << it 
  				if (debug)
  					println RoleBasedAuthorizationStrategy.GLOBAL + "   " + maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRole("Project Admin").getName() + "   " + crowdUserMap.get(it)
  				authStrat.assignRole(RoleBasedAuthorizationStrategy.GLOBAL, maps.get(RoleBasedAuthorizationStrategy.GLOBAL).getRole("Project Admin"), crowdUserMap.get(it))
  			}
  		}
  		repoUsers.each(){
      		if (crowdUserMap.get(it) != null){
      			Role sampleRole = new Role(key, "(?i)" + key + ".*", permissionSet) 
      			if (debug)
      				println RoleBasedAuthorizationStrategy.PROJECT + "   " + sampleRole.getName()
      			authStrat.addRole(RoleBasedAuthorizationStrategy.PROJECT, sampleRole)
      			if (debug)
      				println RoleBasedAuthorizationStrategy.PROJECT + "   " + maps.get(RoleBasedAuthorizationStrategy.PROJECT).getRole(key).getName() + "   " + crowdUserMap.get(it)
      			authStrat.assignRole(RoleBasedAuthorizationStrategy.PROJECT, maps.get(RoleBasedAuthorizationStrategy.PROJECT).getRole(key), crowdUserMap.get(it))
      		}
    	}
  	} 
}
//Hudson.getInstance().setAuthorizationStrategy(strategy)
stratClass.save()
println "\nEnd of Jenkins Role Based Authorization Strategy Script"
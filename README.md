# Vmware terraform module

This module was created to fill the need to spawn multiple vm's with very dynamic settings and placement.
I am a terragrunt fanboy, but I guess it should work for vanilla terraform.

## Getting Started

I will write under the assumption that you will be using terragrunt. 

### Prerequisites

* Terraform 0.12.20
* terragrunt 0.21.4

### Features

all settings can be set individually on each entry in the instances map. for example

* cpu / memory configuration
* template
* list of extra disks in addition to the root disk
* run either cloudinit or vmware customize
* any number of nics ( well not rly... vmware restriction ) 
* password is being set on windows host

remote_connection is used to make sure the vm is online before running next module in chain. eg. run ansible after


### Installing

Create Directories

```
mkdir -p ~/terraform/module
mkdir -p ~/terragrunt/projects/vmware01
```

Clone repos 

```
cd ~/terraform/module/
git clone https://github.com/Boolman/terraform-module-vmware virtualmachine
git clone https://github.com/Boolman/terraform-module-vmware-data.git data
```

Create the directory structure of terragrunt
```
~/terragrunt/projects/vmware01
+-- terragrunt.hcl
+-- data
|   +-- terragrunt.hcl
+-- vm
|   +-- terragrunt.hcl
```

contents of terragrunt.hcl in root directory
```
remote_state {
  backend = "consul"
  config = {
    address = "127.0.0.1:8500"
    path    = "xxx/${path_relative_to_include()}/terraform.tfstate"
  }
}

terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    env_vars = {
      VSPHERE_USER = "xxx"
      VSPHERE_PASSWORD = "xxx"
      VSPHERE_SERVER = "1.2.3.4"
    }
  }
}

```

contents of terragrunt.hcl in data directory
```
terraform {
  source = "~/terraform/module/data"
}
include {
  path = find_in_parent_folders()
}
inputs = {
        dc        = "dc1"
        cluster   = "cluster01"
        datastore = "ds01"
        vlan      = ["switch1", "switch2"]
        template  = ["template1", "template2"]
}

```
contents of terragrunt.hcl in vm directory
```
terraform {
  source = "~/terraform/module/virtualmachine"
}

include {
  path = find_in_parent_folders()
}

dependency "data" {
        config_path = "../data"
}

locals {
  defaults = { 
  	"extra_disks": [], 
	"customize": true, 
	"folder": "FOLDER1", 
  }
}
inputs = {
  instances = { 
    "myhostname" = merge(local.defaults, { 
	"cpu": "1", 
	"memory": "1024", 
	"template": dependency.data.outputs.template["template1"], 
	"ds": dependency.data.outputs.datastore["ds01"].id, 
	"cluster": dependency.data.outputs.cluster["cluster01"],
	"network": { 
		"interfaces": [
		  { "network": dependency.data.outputs.network["switch1"], "address": "1.1.1.2/24" }, 
		  { "network": dependency.data.outputs.network["switch2"], "address": "10.0.0.10/24" }, 
		], 
		"dns": ["8.8.8.8"], 
		"gateway": "10.0.0.1" 
	}
    }),
  }
}

```

## Running the tests

in the directory where the root terragrunt.hcl exists. run

```
terragrunt apply-all
```

## Built With

* [Terragrunt](https://github.com/gruntwork-io/terragrunt)
* [Terraform](https://www.terraform.io/downloads.html) 

## Contributing

## Authors

* Yours truly

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

# Vmware terraform module

This module was created to fill the need to spawn multiple vm's with very dynamic settings and placement.
I am a terragrunt fanboy, but I guess it should work for vanilla terraform. 

## Getting Started

I will write under the assumption that you will be using terragrunt.

### Prerequisites

Terraform 0.12.20 is the only requirement
terragrunt x

### Features

all settings can be set individually on each entry in the instances map. for example

* cpu / memory configuration
* list of extra disks in addition to the root disk ( size specified in the template ) 
* run either cloudinit or vmware customize
* any number of nics ( well not rly... vmware restriction ) 
* password is being set on windows host
* remote_connection is used to make sure the vm is online before running next module in chain. eg. run ansible after


### Installing

Clone repos 

```
cd terraform/module/
git clone https://github.com/Boolman/terraform-module-vmware virtualmachine
git clone https://github.com/Boolman/terraform-module-vmware-data.git data
```

build terragrunt structure and configuration
```
tree terragrunt/projects/myproject01/
terragrunt.hcl
data
 + terragrunt.hcl
vm
 + erragrunt.hcl

```

root terragrunt.hcl
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

cat data/terragrunt.hcl

```
terraform {
  source = "/path/to/terraform/module/data"
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
cat vm/terragrunt.hcl
```
terraform {
  source = "/path/to/terraform/module/virtualmachine"
}

include {
  path = find_in_parent_folders()
}

dependency "data" {
        config_path = "../data"
}

locals {
  defaults = { "extra_disks": [], "customize": true, "ds": dependency.data.outputs.datastore["ds01"].id, "cluster": dependency.data.outputs.cluster["cluster01"], "folder": "FOLDER1", }
}
inputs = {
  instances = { 
    "myhostname" = merge(local.defaults, { 
	"cpu": "1", 
	"memory": "1024", 
	"template": dependency.data.outputs.template["template1"], 
	"network": { 
		"interfaces": [
		  { "network": dependency.data.outputs.network["switch1"], "address": "1.1.1.2/24" }, 
		  {"network": dependency.data.outputs.network["switch2"], "address": "10.0.0.10/24"}, 
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

* [Terragrunt](https://maven.apache.org/)
* [Terraform](https://www.terraform.io/downloads.html) 

## Contributing

## Authors

* **Billie Thompson** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

# Elasticsearch on AWS using Salt

This is a quick proof of concept on how to install Elasticsearch on a single AWS EC2 instance using Salt.

## Copyright

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>

## Pre-requisites

Before proceeding, you'll need to install [Terraform](https://terraform.io), the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html), and ensure that you have the AWS CLI configured (don't use your root key!) using an IAM user with at least EC2 admin rights.

You must also have an SSH key present at the location `~/.ssh/id_rsa.pub`.

## Deploying the lab

By default, the AWS resources will be provisioned in the US-East-1 region. To deploy in another region, edit the `region` field in the `terraform/main.tf` file.

Run these commands to deploy the node:

```bash
terraform init
terraform apply -var-file=./default.tfvars
```

The apply will output a public DNS name for the instance created. Use this to SSH to the instance, using the user name "ubuntu" and specifying the existing key file you have at the location `~/.ssh/id_rsa`.

Once connected, issue this command to wait for the cloud-init package to finish.

```bash
cloud-init status --wait
```

You should see something like this:

```bash
ubuntu@es-lab-0:~$ cloud-init status --wait
.........................................................................................................................................................................................................................................................................................................................................................
status: done
```

Once complete, you should be able to test connectivity to the local ES installation using these commands:

```bash
ubuntu@es-lab-0:~$ curl localhost:9200
{
  "name" : "Crimson",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "LMo5P25aT-iQk5y7iGcuHg",
  "version" : {
    "number" : "2.4.5",
    "build_hash" : "c849dd13904f53e63e88efc33b2ceeda0b6a1276",
    "build_timestamp" : "2017-04-24T16:18:17Z",
    "build_snapshot" : false,
    "lucene_version" : "5.5.4"
  },
  "tagline" : "You Know, for Search"
}
ubuntu@es-lab-0:~$ curl -XPOST localhost:9200/myindex/doc -d '{"@timestamp":"2019-10-22T06:53:00-4","name":"Josh"}'
{"_index":"myindex","_type":"doc","_id":"AW3zIXLkjCrve4fHkB6S","_version":1,"_shards":{"total":2,"successful":1,"failed":0},"created":true}
```

> **NOTE: Some times it can take a few seconds between when the cloud-init package finishes and when the instance of Elasticsearch responds to the CURL command.**

## Tear-down

To tear-down the lab, issue this command:

```bash
terraform destroy -auto-approve -var-file=./default.tfvars
```

## To-dos

- Add additional EBS volumes for the ES data files
- Create a templated `elasticsearch.yaml` file
- Enhance to allow provisioning of a cluster
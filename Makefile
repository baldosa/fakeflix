TF      := terraform -chdir=terraform
ANSIBLE := cd ansible &&

.PHONY: help infra deps deploy update update-os destroy

help:
	@echo "make infra      - create/modify the Proxmox LXC (terraform apply)"
	@echo "make deps       - install Ansible collections"
	@echo "make deploy     - install/configure everything (idempotent)"
	@echo "make update     - pull newer images & recreate changed containers"
	@echo "                  only some: make update SERVICES=radarr,sonarr"
	@echo "make update-os  - update OS packages + Docker, then the containers"
	@echo "make destroy    - delete the LXC (media on the host is untouched)"

infra:
	$(TF) init -upgrade
	$(TF) apply

deps:
	$(ANSIBLE) ansible-galaxy collection install -r requirements.yml -p collections

deploy: deps
	$(ANSIBLE) ansible-playbook site.yml

update:
	$(ANSIBLE) ansible-playbook update.yml $(if $(SERVICES),-e stack_only=$(SERVICES))

update-os:
	$(ANSIBLE) ansible-playbook update.yml -e update_os=true

destroy:
	$(TF) destroy

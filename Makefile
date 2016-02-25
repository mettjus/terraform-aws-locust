plan: public_ip.txt
	terraform plan

public_ip.txt:
	curl -s ipecho.net/plain > public_ip.txt

destroy:
	terraform destroy
	rm public_ip.txt

apply: public_ip.txt
	terraform apply

prepare-update:
	bash -c scripts/prepare-update.sh
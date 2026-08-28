TERRAFORM ?= terraform
TFLINT    ?= tflint

TF_DIRS := \
	terraform/bootstrap \
	terraform/envs/dev/data \
	terraform/envs/dev/network \
	terraform/envs/dev/platform \
	terraform/envs/prod/data \
	terraform/envs/prod/network \
	terraform/envs/prod/platform

.PHONY: validate fmt tf-validate tflint trivy

# reproduces what CI will enforce
validate: fmt tf-validate tflint trivy

fmt:
	$(TERRAFORM) fmt -check -recursive terraform

tf-validate:
	@for dir in $(TF_DIRS); do \
		echo "==> terraform validate: $$dir"; \
		(cd $$dir && $(TERRAFORM) validate) || exit 1; \
	done

tflint:
	@# --config must be an absolute path: tflint's per-module config lookup during
	@# --recursive doesn't walk upward, so a relative/implicit .tflint.hcl is silently skipped
	$(TFLINT) --init --config="$(CURDIR)/.tflint.hcl"
	$(TFLINT) --recursive --config="$(CURDIR)/.tflint.hcl"

# run via the official image, same as step 2.5 did for image scanning
trivy:
	MSYS_NO_PATHCONV=1 docker run --rm \
		-v "$(CURDIR)/terraform:/terraform" \
		-v "$(CURDIR)/trivy.yaml:/trivy.yaml" \
		-v "$(CURDIR)/.trivyignore:/.trivyignore" \
		aquasec/trivy config --config /trivy.yaml /terraform

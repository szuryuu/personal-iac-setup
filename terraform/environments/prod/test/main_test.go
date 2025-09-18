package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func getRequiredEnvVar(t *testing.T, envVar string) string {
	value := os.Getenv(envVar)
	if value == "" {
		t.Fatalf("Environment variable %s is required but not set", envVar)
	}
	return value
}

func TestTerraformPlan(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "..",
	}

	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)

	assert.Contains(t, planOutput, "azurerm_linux_virtual_machine")
	assert.Contains(t, planOutput, "azurerm_mysql_flexible_server")
	assert.Contains(t, planOutput, "azurerm_virtual_network")
}

func TestTerraformAzureInfrastructure(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// t.Parallel()

	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("test-%s", strings.ToLower(uniqueID))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "..",
		Vars: map[string]any{
			"project_name": projectName,
			"is_terratest": true,
		},
		EnvVars: map[string]string{
			"TF_VAR_subscription_id":     getRequiredEnvVar(t, "TF_VAR_subscription_id"),
			"TF_VAR_resource_group_name": getRequiredEnvVar(t, "TF_VAR_resource_group_name"),
			"TF_VAR_key_vault_name":      getRequiredEnvVar(t, "TF_VAR_key_vault_name"),
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// vmPublicIP := terraform.Output(t, terraformOptions, "vm_public_ip")
	vmPrivateIP := terraform.Output(t, terraformOptions, "vm_private_ip")
	dbFQDN := terraform.Output(t, terraformOptions, "db_fqdn")

	// assert.NotEmpty(t, vmPublicIP)
	assert.NotEmpty(t, vmPrivateIP)
	assert.NotEmpty(t, dbFQDN)
	assert.Contains(t, dbFQDN, "mysql.database.azure.com")
}

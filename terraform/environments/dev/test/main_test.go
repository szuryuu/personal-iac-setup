package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformAzureInfrastructure(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	t.Parallel()

	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("test-%s", strings.ToLower(uniqueID))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "..",
		Vars: map[string]any{
			"project_name": projectName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vmPublicIP := terraform.Output(t, terraformOptions, "vm_public_ip")
	vmPrivateIP := terraform.Output(t, terraformOptions, "vm_private_ip")
	dbFQDN := terraform.Output(t, terraformOptions, "db_fqdn")

	assert.NotEmpty(t, vmPublicIP)
	assert.NotEmpty(t, vmPrivateIP)
	assert.NotEmpty(t, dbFQDN)
	assert.Contains(t, dbFQDN, "mysql.database.azure.com")
}

func TestTerraformPlan(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "..",
	}

	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)

	assert.Contains(t, planOutput, "azurerm_linux_virtual_machine")
	assert.Contains(t, planOutput, "azurerm_mysql_flexible_server")
}

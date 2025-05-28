resource "azapi_resource" "vnet" {
  type = "Microsoft.Network/virtualNetworks@2024-05-01"
  /*
  Use merge with conditional maps to exclude unset ('null') values from the request body, preventing Terraform
  from sending explicit nulls that could trigger unwanted changes during apply or import.
*/
  body = merge(
    {
      properties = merge(
        {
          addressSpace         = { addressPrefixes = reverse(sort(var.address_space)) }
          enableDdosProtection = var.ddos_protection_plan != null ? var.ddos_protection_plan.enable : false
        },
        var.bgp_community == null ? {} : {
          bgpCommunities = { virtualNetworkCommunity = var.bgp_community }
        },
        var.dns_servers == null ? {} : {
          dhcpOptions = { dnsServers = var.dns_servers.dns_servers }
        },
        var.ddos_protection_plan == null ? {} : {
          ddosProtectionPlan = { id = var.ddos_protection_plan.id }
        },
        var.enable_vm_protection == null ? {} : {
          enableVmProtection = var.enable_vm_protection
        },
        var.encryption == null ? {} : {
          encryption = {
            enabled     = var.encryption.enabled
            enforcement = var.encryption.enforcement
          }
        },
        var.flow_timeout_in_minutes == null ? {} : {
          flowTimeoutInMinutes = var.flow_timeout_in_minutes
        },
        var.private_endpoint_vnet_policies == null ? {} : {
          privateEndpointVNetPolicies = var.private_endpoint_vnet_policies
        },
        var.subnets == null ? {} : {
          subnets = [for s in var.subnets : s]
        },
        var.peerings == null ? {} : {
          virtualNetworkPeerings = [for p in var.peerings : p]
        }
      )
    },
    var.extended_location == null ? {} : {
      extendedLocation = {
        name = var.extended_location.name
        type = var.extended_location.type
      }
    }
  )

  location                  = var.location
  name                      = var.name
  parent_id                 = "/subscriptions/${local.subscription_id}/resourceGroups/${var.resource_group_name}"
  schema_validation_enabled = true
  tags                      = var.tags

  depends_on = [azapi_update_resource.allow_drop_unencrypted_vnet]

  lifecycle {
    ignore_changes = [
      body.properties.subnets,
      body.properties.virtualNetworkPeerings # Brownfield import: not managed by the module due to time constraints
    ]
  }
}

resource "azapi_update_resource" "allow_drop_unencrypted_vnet" {
  count = var.encryption != null ? (var.encryption.enforcement == "DropUnencrypted" ? 1 : 0) : 0

  type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  body = {
    properties = {}
  }
  resource_id = "/subscriptions/${local.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Network/subscriptionFeatureRegistrations/AllowDropUnecryptedVnet"
}

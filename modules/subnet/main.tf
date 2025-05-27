resource "azapi_resource" "subnet" {
  type = "Microsoft.Network/virtualNetworks/subnets@2023-11-01"
  body = {
    /*
    Use merge with conditional maps to exclude unset ('null') values from the request body, preventing Terraform
    from sending explicit nulls that could trigger unwanted changes during apply or import.
*/
    properties = merge({
      delegations = var.delegation != null ? [
        for delegation in var.delegation : {
          name = delegation.name
          properties = {
            serviceName = delegation.service_delegation.name
          }
      }] : []
      privateEndpointNetworkPolicies    = var.private_endpoint_network_policies
      privateLinkServiceNetworkPolicies = var.private_link_service_network_policies_enabled == false ? "Disabled" : "Enabled"
      },
      var.address_prefix == null ? {} : {
        addressPrefix = var.address_prefix
      },
      var.address_prefixes == null ? {} : {
        addressPrefixes = var.address_prefixes
      },
      var.default_outbound_access_enabled == null ? {} : {
        defaultOutboundAccess = var.default_outbound_access_enabled
      },
      var.nat_gateway == null ? {} : {
        natGateway = { id = var.nat_gateway.id }
      },
      var.network_security_group == null ? {} : {
        networkSecurityGroup = { id = var.network_security_group.id }
      },
      var.route_table == null ? {} : {
        routeTable = { id = var.route_table.id }
      },
      var.service_endpoints == null ? {} : {
        serviceEndpoints = [for service_endpoint in var.service_endpoints : { service = service_endpoint }]
      },
      var.service_endpoint_policies == null ? {} : {
        serviceEndpointPolicies = [for sep in var.service_endpoint_policies : { id = sep.id }]
      },
      var.sharing_scope == null ? {} : {
        sharingScope = var.sharing_scope
    })
  }
  locks                     = [var.virtual_network.resource_id]
  name                      = var.name
  parent_id                 = var.virtual_network.resource_id
  schema_validation_enabled = true

  depends_on = [
    azapi_update_resource.allow_multiple_address_prefixes_on_subnet,
    azapi_update_resource.allow_deletion_of_ip_prefix_from_subnet,
    azapi_update_resource.enable_shared_vnet
  ]

  lifecycle {
    ignore_changes = [
      body.properties.ipConfigurations,
      body.properties.privateEndpoints
    ]
  }
}

resource "azurerm_role_assignment" "subnet" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.subnet.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azapi_update_resource" "allow_multiple_address_prefixes_on_subnet" {
  count = local.has_multiple_address_prefixes ? 1 : 0

  type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  body = {
    properties = {}
  }
  resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Network/subscriptionFeatureRegistrations/AllowMultipleAddressPrefixesOnSubnet"
}

resource "azapi_update_resource" "allow_deletion_of_ip_prefix_from_subnet" {
  count = local.has_multiple_address_prefixes ? 1 : 0

  type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  body = {
    properties = {}
  }
  resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Network/subscriptionFeatureRegistrations/AllowDeletionOfIpPrefixFromSubnet"
}

resource "azapi_update_resource" "enable_shared_vnet" {
  count = var.sharing_scope == "Tenant" ? 1 : 0

  type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  body = {
    properties = {}
  }
  resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Network/subscriptionFeatureRegistrations/EnableSharedVNet"
}

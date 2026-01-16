// ===============================
// Network Resources Module
// ===============================

@description('Location for all resources')
param location string

@description('Virtual Network name')
param vnetName string

@description('Address prefix for VNet')
param addressPrefix string

@description('WAN Subnet name')
param wanSubnetName string

@description('WAN Subnet prefix')
param wanSubnetPrefix string

@description('LAN Subnet name')
param lanSubnetName string

@description('LAN Subnet prefix')
param lanSubnetPrefix string

@description('Route table name')
param routeTableName string

@description('Next hop IP address for default route')
param nextHopIpAddress string

@description('Network Security Group name')
param nsgName string

// ===============================
// Network Security Group
// ===============================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          description: 'Allow HTTPS management access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-SSH-Inbound'
        properties: {
          description: 'Allow SSH management access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-VPN-IPSec-Inbound'
        properties: {
          description: 'Allow IPSec VPN'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '500'
            '4500'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ===============================
// Route Table
// ===============================
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'default-via-sonicwall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
    ]
  }
}

// ===============================
// Virtual Network
// ===============================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: wanSubnetName
        properties: {
          addressPrefix: wanSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: lanSubnetName
        properties: {
          addressPrefix: lanSubnetPrefix
          routeTable: {
            id: routeTable.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ===============================
// Outputs
// ===============================
output vnetId string = vnet.id
output vnetName string = vnet.name
output wanSubnetId string = vnet.properties.subnets[0].id
output lanSubnetId string = vnet.properties.subnets[1].id
output routeTableId string = routeTable.id
output nsgId string = nsg.id
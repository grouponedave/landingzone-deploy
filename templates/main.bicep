// ===============================
// SonicWall NSv 270 Azure Deployment
// Main Bicep Template - GitHub Version
// ===============================

@description('Client ID in ALL CAPS (e.g., ABC, XYZ)')
@minLength(2)
@maxLength(10)
param clientId string

@description('Tenant email domain (e.g., contoso.com)')
param tenantDomain string

@description('Azure region for deployment')
@allowed([
  'westus2'
  'westus3'
])
param location string = 'westus2'

@description('SonicWall management username')
param adminUsername string = 'management'

@description('SonicWall management password')
@secure()
@minLength(12)
param adminPassword string

@description('VM size for SonicWall NSv')
@allowed([
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
])
param vmSize string = 'Standard_D2s_v5'

@description('Deploy timestamp for unique naming')
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

// GitHub repository information for module references
@description('GitHub repository URL base (for modules)')
param githubRepoBase string = 'https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/templates'

// ===============================
// Variables
// ===============================
var resourceGroupName = '${clientId}-RG'
var fwResourceGroupName = '${clientId}-FW-RG'
var vnetName = '${clientId}-VNET'
var addressPrefix = '10.254.0.0/23'
var wanSubnetName = '${clientId}-WAN-SUBNET'
var wanSubnetPrefix = '10.254.0.0/24'
var lanSubnetName = '${clientId}-LAN-SUBNET'
var lanSubnetPrefix = '10.254.1.0/24'
var wanStaticIp = '10.254.0.4'
var lanStaticIp = '10.254.1.4'
var publicIpName = '${clientId}FW1-IP'
var dnsLabel = toLower('${clientId}-fw1')
var routeTableName = '${clientId}-FW1-ROUTE'
var nsgName = '${clientId}-WAN-X1-nsg'

// ===============================
// Network Module (from GitHub)
// ===============================
module network '${githubRepoBase}/modules/network.bicep' = {
  name: 'network-deployment-${deploymentTimestamp}'
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: addressPrefix
    wanSubnetName: wanSubnetName
    wanSubnetPrefix: wanSubnetPrefix
    lanSubnetName: lanSubnetName
    lanSubnetPrefix: lanSubnetPrefix
    routeTableName: routeTableName
    nextHopIpAddress: lanStaticIp
    nsgName: nsgName
  }
}

// ===============================
// Public IP
// ===============================
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
    idleTimeoutInMinutes: 4
  }
}

// ===============================
// Network Interfaces
// ===============================
resource wanNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${clientId}-WAN-X1'
  location: location
  properties: {
    enableIPForwarding: true
    enableAcceleratedNetworking: false
    networkSecurityGroup: {
      id: network.outputs.nsgId
    }
    ipConfigurations: [
      {
        name: '${clientId}-WAN-X1-ipconfig'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: wanStaticIp
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: network.outputs.wanSubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource lanNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${clientId}-LAN-X0'
  location: location
  properties: {
    enableIPForwarding: true
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: '${clientId}-LAN-X0-ipconfig'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: lanStaticIp
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: network.outputs.lanSubnetId
          }
        }
      }
    ]
  }
}

// ===============================
// SonicWall VM Module (from GitHub)
// ===============================
module sonicwallVm '${githubRepoBase}/modules/sonicwall-vm.bicep' = {
  name: 'sonicwall-vm-deployment-${deploymentTimestamp}'
  params: {
    location: location
    clientId: clientId
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    wanNicId: wanNic.id
    lanNicId: lanNic.id
    publicIpId: publicIp.id
  }
  dependsOn: [
    wanNic
    lanNic
    publicIp
  ]
}

// ===============================
// Outputs
// ===============================
output vmName string = sonicwallVm.outputs.vmName
output vmId string = sonicwallVm.outputs.vmId
output publicIpAddress string = publicIp.properties.ipAddress
output fqdn string = publicIp.properties.dnsSettings.fqdn
output wanPrivateIp string = wanStaticIp
output lanPrivateIp string = lanStaticIp
output vnetName string = network.outputs.vnetName
output managementUrl string = 'https://${publicIp.properties.ipAddress}'
output sshCommand string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress}'
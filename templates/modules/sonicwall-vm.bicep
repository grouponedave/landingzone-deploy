// ===============================
// SonicWall VM Module
// ===============================

@description('Location for resources')
param location string

@description('Client ID prefix')
param clientId string

@description('VM size')
param vmSize string

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('WAN NIC ID')
param wanNicId string

@description('LAN NIC ID')
param lanNicId string

@description('Public IP ID')
param publicIpId string

// SonicWall Marketplace Image
var imageReference = {
  publisher: 'sonicwall-inc'
  offer: 'sonicwall-nsz-azure'
  sku: 'snwl-nsv-scx'
  version: 'latest'
}

var plan = {
  name: 'snwl-nsv-scx'
  publisher: 'sonicwall-inc'
  product: 'sonicwall-nsz-azure'
}

var vmName = '${clientId}FW1'

// ===============================
// SonicWall Virtual Machine
// ===============================
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  plan: plan
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: false
        vTpmEnabled: true
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
        diskSizeGB: 60
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: wanNicId
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
        {
          id: lanNicId
          properties: {
            primary: false
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ===============================
// Outputs
// ===============================
output vmId string = vm.id
output vmName string = vm.name

/**************/
/* PARAMETERS */
/*************/

@description('Admin username for the servers')
param adminUsername string

@description('Password for the admin account on the servers')
@secure()
param adminPassword string

@description('Location for all resources.')
param location string = resourceGroup().location

/**************/
/* VARIABLES */
/*************/

var vmSize = 'Standard_D2as_v5'
var secAddrSpace = '10.40.0.0/16'
var secAzFWSubnet = '10.40.0.0/24'
var secAppGWSubnet = '10.40.1.0/24'
var webAddrSpace = '10.41.0.0/16'
var webAppSubnet = '10.41.0.0/24'
var bastionSubnet = '10.41.1.0/24'

/**************/
/* RESOURCES */
/*************/

resource secureHub_Vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'secHub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        secAddrSpace
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource azfw_Subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: secureHub_Vnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: secAzFWSubnet
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource appGW_Subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: secureHub_Vnet
  name: 'AppGW'
  properties: {
    addressPrefix: secAppGWSubnet
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    azfw_Subnet
  ]
}

resource toFW_RouteTable 'Microsoft.Network/routeTables@2022-11-01' = {
  name: 'toFW_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to_vm'
        properties: {
          addressPrefix: webAppSubnet
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall1.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource fromWeb_RouteTable 'Microsoft.Network/routeTables@2022-11-01' = {
  name: 'fromWeb_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to_fw'
        properties: {
          addressPrefix: secAppGWSubnet
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall1.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource web_Vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'web_Vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        webAddrSpace
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource web_Subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: web_Vnet
  name: 'app'
  properties: {
    addressPrefix: webAppSubnet
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource secureHubTowebPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-11-01' = {
  name: 'secureHubTowebPeering'
  parent: secureHub_Vnet
  properties: {
    allowForwardedTraffic: false
    allowGatewayTransit: false
    remoteVirtualNetwork: {
      id: web_Vnet.id
    }
  }
  dependsOn: [
    AppGateway
    firewall1
    bastionHost
  ]
}

resource webPeeringTosecureHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'webPeeringTosecureHub'
  parent: web_Vnet
  properties: {
    allowForwardedTraffic: false
    allowGatewayTransit: false
    remoteVirtualNetwork: {
      id: secureHub_Vnet.id
    }
  }
  dependsOn: [
    AppGateway
    firewall1
    bastionHost
  ]
}

resource bastion_Subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: web_Vnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnet
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    web_Subnet
  ]
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-11-01' = {
  name: 'bastion'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableFileCopy: true
    enableIpConnect: true
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'IpConfig1'
        properties: {
          subnet: {
            id: bastion_Subnet.id
          }
          publicIPAddress: {
            id: bastion_publicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    webWinVM
  ]
}

resource bastion_publicIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource azfw_PublicIpAddress 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'azfw_PublicIpAddress'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource policy1 'Microsoft.Network/firewallPolicies@2022-11-01' = {
  name: 'AzfwPolicy1'
  location: location
  properties: {
    sku: {
      tier: 'Premium'
    }
    threatIntelMode: 'Alert'
    intrusionDetection: {
      mode: 'Alert'
    }
    dnsSettings: {
      enableProxy: true
    }
  }
}

resource NetworkRuleCollectionGroup1 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: policy1
  name: 'NetworkRuleCollectionGroup1'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRuleCollection'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-All'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall1 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  name: 'AzFwFirewall'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: azfw_Subnet.id
          }
          publicIPAddress: {
            id: azfw_PublicIpAddress.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: policy1.id
    }
  }
  dependsOn: [
    AppGateway
  ]
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'loganalytics${location}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
  }
}

resource azfwDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'AzureFW-diags'
  scope: firewall1
  properties: {
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWNetworkRule'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWApplicationRule'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWNatRule'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWThreatIntel'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWIdpsSignature'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWDnsQuery'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWFqdnResolveFailure'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWFatFlow'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWFlowTrace'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWApplicationRuleAggregation'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWNetworkRuleAggregation'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
      {
        category: 'AZFWNatRuleAggregation'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

/* Windows VM */
resource webWinVM_netInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'webWinVM_nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: web_Subnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
}

resource webWinVM 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'webWinVM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: 'webWinVM'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: webWinVM_netInterface.id
        }
      ]
    }
  }
}

resource webWinVM_IIS 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: webWinVM
  name: 'webWinVM_IIS'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.4'
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/bcosden/AppGW_AzFw_TLS_Lab/master/scripts/install.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File install.ps1'
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kvcerts${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    enableRbacAuthorization: false
    enableSoftDelete: false /* Will be deprecated in Feb 2025, but for now enable hard delete of vault so name can be reused immediately */
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          certificates: [
            'Get'
            'List'
            'Create'
            'Import'
            'Update'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
          ]
          secrets: [
            'Get'
          ]
        }
      }      
    ]
    tenantId: tenant().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'kv_mgd_identity'
  location: location
}

resource appGW_PublicIpAddress 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'appGW_PublicIpAddress'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource AppGateway 'Microsoft.Network/applicationGateways@2022-11-01' = {
  name: 'AppGW'
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGW_Subnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: appGW_PublicIpAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'http'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool01'
        properties: {
          backendAddresses: [
            {
              ipAddress: webWinVM_netInterface.properties.ipConfigurations[0].properties.privateIPAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'HTTPSetting01'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'HTTPListener01'
        properties: {
          firewallPolicy: {
            id: AppGW_WAFPolicy.id
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'AppGW', 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'AppGW', 'http')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'HTTPRoutingRule01'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'AppGW', 'HTTPListener01')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'AppGW', 'BackendPool01')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'AppGW', 'HTTPSetting01')
          }
        }
      }
    ]
    enableHttp2: false
    firewallPolicy: {
      id: AppGW_WAFPolicy.id
    }
  }
}

resource AppGW_WAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: 'AppGW_WAFPolicy'
  location: location
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
        }
      ]
    }
  }
}

output AppGW_PublicIPAddress string = appGW_PublicIpAddress.properties.ipAddress
output Url string = 'http://${appGW_PublicIpAddress.properties.ipAddress}/cgi-bin/env.pl'

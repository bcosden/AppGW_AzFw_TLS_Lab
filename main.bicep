targetScope='subscription'

param rgName string
param rgLocation string

param adminUsername string
@secure()
param adminPassword string

resource newRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: rgName
  location: rgLocation
}

module security 'security.bicep' = {
  name: 'security'
  scope: newRG
  params: {
    location: rgLocation
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

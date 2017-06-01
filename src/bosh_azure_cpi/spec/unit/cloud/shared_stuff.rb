shared_context "shared stuff" do
  let(:cloud) { mock_cloud }
  let(:registry) { mock_registry }
  let(:azure_properties) { mock_azure_properties }
  let(:azure_properties_managed) {
    mock_azure_properties_merge({
      'use_managed_disks' => true
    })
  }
  let(:managed_cloud) { mock_cloud(mock_cloud_properties_merge({'azure' => {'use_managed_disks' => true}})) }

  let(:client2) { instance_double('Bosh::AzureCloud::AzureClient2') }
  let(:blob_manager) { instance_double('Bosh::AzureCloud::BlobManager') }
  let(:disk_manager) { instance_double('Bosh::AzureCloud::DiskManager') }
  let(:storage_account_manager) { instance_double('Bosh::AzureCloud::StorageAccountManager') }
  let(:table_manager) { instance_double('Bosh::AzureCloud::TableManager') }
  let(:stemcell_manager) { instance_double('Bosh::AzureCloud::StemcellManager') }
  let(:disk_manager2) { instance_double('Bosh::AzureCloud::DiskManager2') }
  let(:stemcell_manager2) { instance_double('Bosh::AzureCloud::StemcellManager2') }
  let(:light_stemcell_manager) { instance_double('Bosh::AzureCloud::LightStemcellManager') }
  let(:vm_manager) { instance_double('Bosh::AzureCloud::VMManager') }

  before do
    allow(Bosh::AzureCloud::AzureClient2).to receive(:new).
      and_return(client2)
    allow(Bosh::AzureCloud::BlobManager).to receive(:new).
      and_return(blob_manager)
    allow(Bosh::AzureCloud::DiskManager).to receive(:new).
      and_return(disk_manager)
    allow(Bosh::AzureCloud::StorageAccountManager).to receive(:new).
      and_return(storage_account_manager)
    allow(Bosh::AzureCloud::TableManager).to receive(:new).
      and_return(table_manager)
    allow(Bosh::AzureCloud::StemcellManager).to receive(:new).
      and_return(stemcell_manager)
    allow(Bosh::AzureCloud::DiskManager2).to receive(:new).
      and_return(disk_manager2)
    allow(Bosh::AzureCloud::StemcellManager2).to receive(:new).
      and_return(stemcell_manager2)
    allow(Bosh::AzureCloud::LightStemcellManager).to receive(:new).
      and_return(light_stemcell_manager)
    allow(Bosh::AzureCloud::VMManager).to receive(:new).
      and_return(vm_manager)
  end
end

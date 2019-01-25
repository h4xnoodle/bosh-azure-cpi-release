# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe 'cpi.json.erb' do
  let(:jobs_root) { File.join(File.dirname(__FILE__), '../../../../../../../../', 'jobs') }
  let(:cpi_specification_file) { File.absolute_path(File.join(jobs_root, 'azure_cpi/spec')) }
  let(:cpi_json_erb) { File.read(File.absolute_path(File.join(jobs_root, 'azure_cpi/templates/cpi.json.erb'))) }
  let(:manifest) do
    {
      'properties' => {
        'azure' => {
          'environment' => 'AzureCloud',
          'subscription_id' => 'fake-subscription-id',
          'credentials_source' => 'static',
          'tenant_id' => 'fake-tenant-id',
          'client_id' => 'fake-client-id',
          'client_secret' => 'fake-client-secret',
          'resource_group_name' => 'fake-resource-group-name',
          'storage_account_name' => 'fake-storage-account-name',
          'ssh_user' => 'vcap',
          'ssh_public_key' => 'ssh-rsa ABCDEFGHIJKLMN',
          'default_security_group' => 'fake-default-security-group'
        },
        'registry' => {
          'host' => 'registry-host.example.com',
          'username' => 'admin',
          'password' => 'admin',
          'port' => 25_777
        },
        'blobstore' => {
          'address' => 'blobstore-address.example.com',
          'agent' => {
            'user' => 'agent',
            'password' => 'agent-password'
          }
        },
        'nats' => {
          'address' => 'nats-address.example.com',
          'password' => 'nats-password'
        }
      }
    }
  end
  let(:logger) { Logger.new(STDERR) }

  subject(:parsed_json) do
    context_hash = YAML.load_file(cpi_specification_file)
    context = TemplateEvaluationContext.new(context_hash, manifest)
    renderer = ERBRenderer.new(context)
    parsed_json = JSON.parse(renderer.render(cpi_json_erb))
    parsed_json
  end

  it 'is able to render the erb given most basic manifest properties' do
    expect(subject).to eq(
      'cloud' => {
        'plugin' => 'azure',
        'properties' => {
          'azure' => {
            'environment' => 'AzureCloud',
            'subscription_id' => 'fake-subscription-id',
            'credentials_source' => 'static',
            'tenant_id' => 'fake-tenant-id',
            'client_id' => 'fake-client-id',
            'client_secret' => 'fake-client-secret',
            'resource_group_name' => 'fake-resource-group-name',
            'storage_account_name' => 'fake-storage-account-name',
            'ssh_user' => 'vcap',
            'ssh_public_key' => 'ssh-rsa ABCDEFGHIJKLMN',
            'default_security_group' => 'fake-default-security-group',
            'parallel_upload_thread_num' => 16,
            'debug_mode' => false,
            'keep_failed_vms' => false,
            'enable_telemetry' => false,
            'use_managed_disks' => false,
            'pip_idle_timeout_in_minutes' => 4,
            'enable_vm_boot_diagnostics' => false
          },
          'registry' => {
            'user' => 'admin',
            'password' => 'admin',
            'endpoint' => 'http://admin:admin@registry-host.example.com:25777'
          },
          'agent' => {
            'ntp' => [
              '0.pool.ntp.org',
              '1.pool.ntp.org'
            ],
            'blobstore' => {
              'provider' => 'dav',
              'options' => {
                'endpoint' => 'http://blobstore-address.example.com:25250',
                'user' => 'agent',
                'password' => 'agent-password'
              }
            },
            'mbus' => 'nats://nats:nats-password@nats-address.example.com:4222'
          }
        }
      }
    )
  end

  context 'when parsing the azure property' do
    context 'when the location is specified' do
      before do
        manifest['properties']['azure']['location'] = 'fake-location'
      end

      it 'is able to render location to fake-location' do
        expect(subject['cloud']['properties']['azure']['location']).to eq('fake-location')
      end
    end

    context 'when credentials_source is invalid' do
      before do
        manifest['properties']['azure']['credentials_source'] = 'invalid-value'
      end

      it 'should raise an error' do
        expect { subject }.to raise_error(/The value of "credentials_source" is invalid. Possible values: "static" and "managed_identity"/)
      end
    end

    context 'when credentials_source is managed_identity' do
      before do
        manifest['properties']['azure']['credentials_source'] = 'managed_identity'
        manifest['properties']['azure']['tenant_id'] = nil
        manifest['properties']['azure']['client_id'] = nil
        manifest['properties']['azure']['client_secret'] = nil
      end

      context 'when default managed identity is system assigned' do
        before do
          manifest['properties']['azure']['default_managed_identity'] = {
            'type' => 'SystemAssigned'
          }
        end

        it 'should use system assigned managed identity and allow tenant_id/client_id/client_secret to be nil' do
          expect(subject['cloud']['properties']['azure']['default_managed_identity']['type']).to eq('SystemAssigned')
          expect(subject['cloud']['properties']['azure']['default_managed_identity']['user_assigned_identity_name']).to be_nil
          expect(subject['cloud']['properties']['azure']['tenant_id']).to be_nil
          expect(subject['cloud']['properties']['azure']['client_id']).to be_nil
          expect(subject['cloud']['properties']['azure']['client_secret']).to be_nil
        end

        context 'when user_assigned_identity_name is specified' do
          before do
            manifest['properties']['azure']['default_managed_identity'] = {
              'type' => 'SystemAssigned'
            }
          end

          it 'should ignore user_assigned_identity_name' do
            expect(subject['cloud']['properties']['azure']['default_managed_identity']['type']).to eq('SystemAssigned')
            expect(subject['cloud']['properties']['azure']['default_managed_identity']['user_assigned_identity_name']).to be_nil
            expect(subject['cloud']['properties']['azure']['tenant_id']).to be_nil
            expect(subject['cloud']['properties']['azure']['client_id']).to be_nil
            expect(subject['cloud']['properties']['azure']['client_secret']).to be_nil
          end
        end
      end

      context 'when default managed identity is user assigned' do
        before do
          manifest['properties']['azure']['default_managed_identity'] = {
            'type' => 'UserAssigned',
            'user_assigned_identity_name' => 'fake-identity-name'
          }
        end

        it 'should use user assigned managed identity and allow tenant_id/client_id/client_secret to be nil' do
          expect(subject['cloud']['properties']['azure']['default_managed_identity']['type']).to eq('UserAssigned')
          expect(subject['cloud']['properties']['azure']['default_managed_identity']['user_assigned_identity_name']).to eq('fake-identity-name')
          expect(subject['cloud']['properties']['azure']['tenant_id']).to be_nil
          expect(subject['cloud']['properties']['azure']['client_id']).to be_nil
          expect(subject['cloud']['properties']['azure']['client_secret']).to be_nil
        end
      end

      context 'when default managed identity type is invalid' do
        before do
          manifest['properties']['azure']['default_managed_identity'] = {
            'type' => 'Invalid'
          }
        end

        it 'should raise an error' do
          expect { subject }.to raise_error(/The value of "azure.default_managed_identity.type" is invalid. Possible values: "SystemAssigned" and "UserAssigned"/)
        end
      end
    end

    context 'when credentials_source is static' do
      context 'when client_secret is provided' do
        it 'is able to render client_secret' do
          expect(subject['cloud']['properties']['azure']['tenant_id']).to eq('fake-tenant-id')
          expect(subject['cloud']['properties']['azure']['client_id']).to eq('fake-client-id')
          expect(subject['cloud']['properties']['azure']['client_secret']).to eq('fake-client-secret')
          expect(subject['cloud']['properties']['azure']['default_managed_identity']).to be_nil
        end
      end

      context 'when client_secret is not provided' do
        before do
          manifest['properties']['azure']['client_secret'] = nil
        end

        context 'when certificate is not provided' do
          before do
            manifest['properties']['azure']['certificate'] = nil
          end

          it 'raises an error of missing azure.client_secret and azure.certificate' do
            expect { subject }.to raise_error(/both "client_secret" and "certificate" are not provided/)
          end
        end

        context 'when certificate is provided' do
          before do
            manifest['properties']['azure']['certificate'] = 'fake-certificate-content'
          end

          it 'allows client_secret to be nil' do
            expect(subject['cloud']['properties']['azure']['tenant_id']).to eq('fake-tenant-id')
            expect(subject['cloud']['properties']['azure']['client_id']).to eq('fake-client-id')
            expect(subject['cloud']['properties']['azure']['client_secret']).to be_nil
            expect(subject['cloud']['properties']['azure']['default_managed_identity']).to be_nil
          end
        end
      end
    end

    context 'when the managed disks are enabled' do
      before do
        manifest['properties']['azure']['use_managed_disks'] = true
      end

      it 'is able to render use_managed_disks to true' do
        expect(subject['cloud']['properties']['azure']['use_managed_disks']).to be(true)
      end
    end

    context 'when the keep_failed_vms are enabled' do
      before do
        manifest['properties']['azure']['keep_failed_vms'] = true
      end

      it 'is able to render keep_failed_vms to true' do
        expect(subject['cloud']['properties']['azure']['keep_failed_vms']).to be(true)
      end
    end

    context 'when pip_idle_timeout_in_minutes is set to 20' do
      before do
        manifest['properties']['azure']['pip_idle_timeout_in_minutes'] = 20
      end

      it 'is able to render pip_idle_timeout_in_minutes to 20' do
        expect(subject['cloud']['properties']['azure']['pip_idle_timeout_in_minutes']).to be(20)
      end
    end

    context 'when the default security group is not provided' do
      before do
        manifest['properties']['azure']['default_security_group'] = nil
      end

      it 'allows default_security_group to be empty string' do
        expect(subject['cloud']['properties']['azure']['default_security_group']).to be_nil
      end
    end

    context 'when the storage account is not provided' do
      before do
        manifest['properties']['azure']['storage_account_name'] = nil
      end

      context 'when the managed disks are enabled' do
        before do
          manifest['properties']['azure']['use_managed_disks'] = true
        end

        it 'allows storage_account_name to be nil' do
          expect(subject['cloud']['properties']['azure']['storage_account_name']).to be_nil
        end
      end

      context 'when the managed disks are disabled' do
        it 'raises an error of missing storage_account_name' do
          expect { subject }.to raise_error(/storage_account_name cannot be nil if use_managed_disks is false/)
        end
      end
    end

    context 'when the ssh public key is not provided' do
      before do
        manifest['properties']['azure']['ssh_public_key'] = nil
      end

      it 'raises an error of missing ssh_public_key' do
        expect { subject }.to raise_error(/"ssh_public_key" is not set/)
      end
    end

    context 'when the enable_telemetry is disabled' do
      before do
        manifest['properties']['azure']['enable_telemetry'] = false
      end

      it 'is able to render enable_telemetry to false' do
        expect(subject['cloud']['properties']['azure']['enable_telemetry']).to be(false)
      end
    end

    context 'when the enable_telemetry is enabled' do
      before do
        manifest['properties']['azure']['enable_telemetry'] = true
      end

      it 'is able to render enable_telemetry to true' do
        expect(subject['cloud']['properties']['azure']['enable_telemetry']).to be(true)
      end
    end

    context 'when the enable_vm_boot_diagnostics is disabled' do
      before do
        manifest['properties']['azure']['enable_vm_boot_diagnostics'] = false
      end

      it 'is able to render enable_vm_boot_diagnostics to false' do
        expect(subject['cloud']['properties']['azure']['enable_vm_boot_diagnostics']).to be(false)
      end
    end

    context 'when the enable_vm_boot_diagnostics is enabled' do
      before do
        manifest['properties']['azure']['enable_vm_boot_diagnostics'] = true
      end

      it 'is able to render enable_vm_boot_diagnostics to true' do
        expect(subject['cloud']['properties']['azure']['enable_vm_boot_diagnostics']).to be(true)
      end
    end

    context 'when the environment is AzureStack' do
      before do
        manifest['properties']['azure']['environment'] = 'AzureStack'
        manifest['properties']['azure']['azure_stack'] = {}
      end

      context 'when all the required properties are provided' do
        before do
          manifest['properties']['azure']['azure_stack']['resource'] = 'fake-token-resource'
        end

        it 'parses the AzureStack properties' do
          expect(subject['cloud']['properties']['azure']['azure_stack']).to eq(
            'domain' => 'local.azurestack.external',
            'authentication' => 'AzureAD',
            'resource' => 'fake-token-resource',
            'endpoint_prefix' => 'management'
          )
        end
      end

      context 'when maximal properties are provided' do
        before do
          manifest['properties']['azure']['azure_stack']['domain']          = 'fake-domain'
          manifest['properties']['azure']['azure_stack']['authentication']  = 'fake-authentication'
          manifest['properties']['azure']['azure_stack']['resource']        = 'fake-token-resource'
          manifest['properties']['azure']['azure_stack']['endpoint_prefix'] = 'fake-endpoint-prefix'
        end

        it 'parses the AzureStack properties' do
          expect(subject['cloud']['properties']['azure']['azure_stack']).to eq(
            'domain' => 'fake-domain',
            'authentication' => 'fake-authentication',
            'resource' => 'fake-token-resource',
            'endpoint_prefix' => 'fake-endpoint-prefix'
          )
        end
      end

      context 'when azure_stack.resource is invalid' do
        before do
          manifest['properties']['azure']['azure_stack']['domain'] = 'fake-domain'
          manifest['properties']['azure']['azure_stack']['authentication'] = 'fake-authentication'
        end

        context 'when azure_stack.resource is nil' do
          before do
            manifest['properties']['azure']['azure_stack']['resource'] = nil
          end

          it 'raises an error of missing azure_stack.resource' do
            expect { subject }.to raise_error(/"resource" must be set for AzureStack/)
          end
        end

        context 'when azure_stack.resource is empty' do
          before do
            manifest['properties']['azure']['azure_stack']['resource'] = ''
          end

          it 'raises an error of missing azure_stack.resource' do
            expect { subject }.to raise_error(/"resource" must be set for AzureStack/)
          end
        end
      end
    end

    context 'when isv_tracking_guid is provided' do
      context 'when guid is invalid' do
        before do
          manifest['properties']['azure']['isv_tracking_guid'] = 'fake-tracking-guid'
        end

        it 'raise an error' do
          expect { subject }.to raise_error('Invalid "isv_tracking_guid", length of guid must be 36.')
        end
      end

      context 'when guid is valid' do
        before do
          manifest['properties']['azure']['isv_tracking_guid'] = 'cd237ace-be2a-425c-a30f-dd91d5e93d96'
        end

        it 'is able to render isv_tracking_guid' do
          expect(subject['cloud']['properties']['azure']['isv_tracking_guid']).to eq('cd237ace-be2a-425c-a30f-dd91d5e93d96')
        end
      end
    end
  end

  context 'when parsing the registry property' do
    context 'when the registry endpoint is specified' do
      registry_endpoint = 'http://fake-username:fake-password@fake-registry-endpoint:fake-port'
      before do
        manifest['properties']['registry']['endpoint'] = registry_endpoint
      end

      it 'can parse the endpoint' do
        expect(subject['cloud']['properties']['registry']['endpoint']).to eq(registry_endpoint)
      end
    end

    context 'when the registry endpoint is not specified' do
      it 'can parse the endpoint using the host, port, username and password' do
        username = manifest['properties']['registry']['username']
        password = manifest['properties']['registry']['password']
        host = manifest['properties']['registry']['host']
        port = manifest['properties']['registry']['port']
        endpoint = "http://#{username}:#{password}@#{host}:#{port}"
        expect(subject['cloud']['properties']['registry']['endpoint']).to eq(endpoint)
      end
    end

    context 'when the registry password includes special characters' do
      special_chars_password = '=!@#$%^&*/-+?='
      before do
        manifest['properties']['registry']['password'] = special_chars_password
      end

      it 'encodes the password with special characters in the registry URL' do
        registry_uri = URI(subject['cloud']['properties']['registry']['endpoint'])
        expect(URI.decode(registry_uri.password)).to eq(special_chars_password)
      end
    end

    context 'when registry settings are not specified' do
      let(:manifest) do
        {
          'properties' => {
            'azure' => {
              'environment' => 'AzureCloud',
              'subscription_id' => 'fake-subscription-id',
              'credentials_source' => 'static',
              'tenant_id' => 'fake-tenant-id',
              'client_id' => 'fake-client-id',
              'client_secret' => 'fake-client-secret',
              'resource_group_name' => 'fake-resource-group-name',
              'storage_account_name' => 'fake-storage-account-name',
              'ssh_user' => 'vcap',
              'ssh_public_key' => 'ssh-rsa ABCDEFGHIJKLMN',
              'default_security_group' => 'fake-default-security-group'
            },
            'blobstore' => {
              'address' => 'blobstore-address.example.com',
              'agent' => {
                'user' => 'agent',
                'password' => 'agent-password'
              }
            },
            'nats' => {
              'address' => 'nats-address.example.com',
              'password' => 'nats-password'
            }
          }
        }
      end

      it 'should not include registry settings in json' do
        expect(subject['cloud']['properties'].key?('registry')).to be_falsy
      end
    end
  end

  context 'when parsing the agent property' do
    context 'when using an s3 blobstore' do
      let(:rendered_blobstore) { subject['cloud']['properties']['agent']['blobstore'] }

      context 'when provided a minimal configuration' do
        before do
          manifest['properties']['blobstore'].merge!(
            'provider' => 's3',
            'bucket_name' => 'my_bucket',
            'access_key_id' => 'blobstore-access-key-id',
            'secret_access_key' => 'blobstore-secret-access-key'
          )
        end

        it 'renders the s3 provider section with the correct defaults' do
          expect(rendered_blobstore).to eq(
            'provider' => 's3',
            'options' => {
              'bucket_name' => 'my_bucket',
              'access_key_id' => 'blobstore-access-key-id',
              'secret_access_key' => 'blobstore-secret-access-key',
              'use_ssl' => true,
              'port' => 443,
              's3_force_path_style' => false
            }
          )
        end
      end
    end

    context 'when using a local blobstore' do
      let(:rendered_blobstore) { subject['cloud']['properties']['agent']['blobstore'] }

      context 'when provided a minimal configuration' do
        before do
          manifest['properties']['blobstore'].merge!(
            'provider' => 'local',
            'path' => '/fake/path'
          )
        end

        it 'renders the local provider section with the correct defaults' do
          expect(rendered_blobstore).to eq(
            'provider' => 'local',
            'options' => {
              'blobstore_path' => '/fake/path'
            }
          )
        end
      end

      context 'when provided an incomplete configuration' do
        before do
          manifest['properties']['blobstore'].merge!(
            'provider' => 'local'
          )
        end

        it 'raises an error' do
          expect { rendered_blobstore }.to raise_error(/Can't find property 'blobstore.path'/)
        end
      end
    end
  end
end

class TemplateEvaluationContext
  attr_reader :name, :index
  attr_reader :properties, :raw_properties
  attr_reader :spec

  def initialize(spec, manifest)
    @name = spec['job']['name'] if spec['job'].is_a?(Hash)
    @index = spec['index']
    properties = {}
    spec['properties'].each do |name, x|
      default = x['default']
      copy_property(properties, manifest['properties'], name, default)
    end
    @properties = openstruct(properties)
    @raw_properties = properties
    @spec = openstruct(spec)
  end

  def recursive_merge(hash, other)
    hash.merge(other) do |_, old_value, new_value|
      if old_value.class == Hash && new_value.class == Hash
        recursive_merge(old_value, new_value)
      else
        new_value
      end
    end
  end

  def get_binding
    binding.taint
  end

  def p(*args)
    names = Array(args[0])
    names.each do |name|
      result = lookup_property(@raw_properties, name)
      return result unless result.nil?
    end
    return args[1] if args.length == 2

    raise UnknownProperty, names
  end

  def if_p(*names)
    values = names.map do |name|
      value = lookup_property(@raw_properties, name)
      return ActiveElseBlock.new(self) if value.nil?

      value
    end
    yield *values
    InactiveElseBlock.new
  end

  private

  def copy_property(dst, src, name, default = nil)
    keys = name.split('.')
    src_ref = src
    dst_ref = dst
    keys.each do |key|
      src_ref = src_ref[key]
      break if src_ref.nil? # no property with this name is src
    end
    keys[0..-2].each do |key|
      dst_ref[key] ||= {}
      dst_ref = dst_ref[key]
    end
    dst_ref[keys[-1]] ||= {}
    dst_ref[keys[-1]] = src_ref.nil? ? default : src_ref
  end

  def openstruct(object)
    case object
    when Hash
      mapped = object.each_with_object({}) { |(k, v), h| h[k] = openstruct(v); }
      OpenStruct.new(mapped)
    when Array
      object.map { |item| openstruct(item) }
    else
      object
    end
  end

  def lookup_property(collection, name)
    keys = name.split('.')
    ref = collection
    keys.each do |key|
      ref = ref[key]
      return nil if ref.nil?
    end
    ref
  end

  class UnknownProperty < StandardError
    def initialize(names)
      @names = names
      super("Can't find property '#{names.join("', or '")}'")
    end
  end

  class ActiveElseBlock
    def initialize(template)
      @context = template
    end

    def else
      yield
    end

    def else_if_p(*names, &block)
      @context.if_p(*names, &block)
    end
  end

  class InactiveElseBlock
    def else; end

    def else_if_p(*_)
      InactiveElseBlock.new
    end
  end
end

class ERBRenderer
  def initialize(context)
    @context = context
  end

  def render(erb_content)
    erb = ERB.new(erb_content)
    erb.result(@context.get_binding)
  end
end

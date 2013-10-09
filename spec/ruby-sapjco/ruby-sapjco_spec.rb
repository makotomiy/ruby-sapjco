require_relative "../spec_helper.rb"
require 'ruby-sapjco'
require 'yaml'

describe SapJCo::RubyDestinationDataProvider do
  it "should have destination properties filled correctly" do
    ddp = SapJCo::RubyDestinationDataProvider.new(SapJCo::Configuration.configuration)
    props = ddp.get_destination_properties(SapJCo::Configuration.configuration['default_destination'])
    # You should define an Expectations class in your /spec/spec_helper.rb to match what ever you
    # have in your /config.yml (which you also need to create)

    props.get('jco.client.ashost').should eq EXPECTATIONS[:ashost]
    props.get('jco.client.sysnr').should eq EXPECTATIONS[:sysnr]
    props.get('jco.client.client').should eq EXPECTATIONS[:client]
    props.get('jco.client.lang').should eq EXPECTATIONS[:lang]
    props.get('jco.client.user').should eq EXPECTATIONS[:user]
    props.get('jco.client.passwd').should eq EXPECTATIONS[:passwd]
  end
end

describe SapJCo::Function do
  describe "execute" do
    it "should import parameters" do
      func =  SapJCo::Function.new(:STFC_CONNECTION)

      out = func.execute do |params|
        params[:REQUTEXT] = 'Hello SAP!'
      end
      expect(out[:ECHOTEXT]).to eq 'Hello SAP!'

      expect(func.execute({REQUTEXT: 'Hello SAP!'})[:ECHOTEXT]).to eq 'Hello SAP!'
    end

    it "should handle SAP structures correctly" do
      func =  SapJCo::Function.new(:RFC_SYSTEM_INFO)

      out = func.execute
      expect(out[:RFCSI_EXPORT]).to_not be nil
      expect(out[:RFCSI_EXPORT][:RFCHOST2]).to eq EXPECTATIONS[:rfchost]
    end

    it "should handle output tables correctly" do
      func =  SapJCo::Function.new(:BAPI_COMPANYCODE_GETLIST)

      out = func.execute
      expect(out[:COMPANYCODE_LIST].class).to eq Array
      expect(out[:COMPANYCODE_LIST][0][:COMP_CODE]).to eq EXPECTATIONS[:company_code_0]
    end
  end

  describe "metadata" do
    it "should have metadata available" do
      company_code_rfc =  SapJCo::Function.new(:BAPI_COMPANYCODE_GETLIST)
      sys_info_rfc =  SapJCo::Function.new(:RFC_SYSTEM_INFO)

      expect(company_code_rfc.metadata[:function]).to eq'BAPI_COMPANYCODE_GETLIST'
      expect(company_code_rfc.metadata[:import_parameters].length).to eq 0
      expect(company_code_rfc.metadata[:tables][:COMPANYCODE_LIST][:fields][:COMP_CODE][:type]).to eq 'CHAR'
      expect(company_code_rfc.metadata[:tables][:COMPANYCODE_LIST][:fields][:COMP_CODE][:description]).to eq 'Company Code'
      expect(company_code_rfc.metadata[:export_parameters][:RETURN][:type]).to eq 'STRUCTURE'
      expect(company_code_rfc.metadata[:export_parameters][:RETURN][:fields][:CODE][:type]).to eq 'CHAR'
      #company_code_rfc[:tables]
    end
  end

  describe "help" do
    it "should create html documentation" do
      company_code_rfc =  SapJCo::Function.new(:BAPI_COMPANYCODE_GETLIST)
      company_code_rfc.help false
      expect(File.exists?('BAPI_COMPANYCODE_GETLIST.html')).to be true
      File.delete('BAPI_COMPANYCODE_GETLIST.html')
    end
  end
end
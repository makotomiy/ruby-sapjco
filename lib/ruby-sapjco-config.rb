require 'ruby-sapjco-env'

module SapJCo
  class Configuration
    def self.configure(configuration={})
      SapJCo.log.info ">>> Default SAPJCo destination has been set to '#{configuration['default_destination']}' <<<" if configuration.has_key? 'default_destination'

      config_path = ENV['SAPJCO_CONFIG'] || 'config/sapjco.yml'
      if File.exists? config_path
        SapJCo.log.info "Configuring SAPJCo from #{File.expand_path(config_path)}."
        @@configuration =  YAML::load(File.open(config_path))
        @@configuration.merge!(configuration)
      else
        @@configuration = configuration
        SapJCo.log.warn "No configuration file could be located so defaulting to empty configuration." unless @@configuration
      end


      if(!Environment.destination_data_provider_registered?)
        destination_data_provider = RubyDestinationDataProvider.new(@@configuration)
        Environment.register_destination_data_provider(destination_data_provider)
      end
      @@configuration
    end

    def self.configuration
      @@configuration
    end
  end

  class DestinationAssistant
    include  SapJCo
    java_import com.sap.conn.jco.JCoDestinationManager

    def initialize(destination_name)
      @failed = false
      @destination_name = destination_name
      @original_destination = JCoDestinationManager.get_destination @destination_name.to_s
      @active_destination = @original_destination
    end

    def destination
      begin
        if @failed
          attempt_reconnection
        else
          @active_destination.ping
          @failed = false
        end
        @active_destination
      rescue Exception => e
        SapJCo.log.error "Failed to connect to destination. #{e.message} "
        failover_if_applicable(e)
      end

    end

    def failover_if_applicable(e)
      error_keys = %w{JCO_ERROR_LOGON_FAILURE JCO_ERROR_COMMUNICATION}
      @fo_destination_name ||= Configuration.configuration['destinations'][@destination_name.to_s]['failover']
      @fo_destination ||= JCoDestinationManager.get_destination(@fo_destination_name) if @fo_destination_name
      if @fo_destination && (e.respond_to?(:key) && error_keys.include?(e.key))
        SapJCo.log.warn "Switching to failover destination #{@fo_destination_name}:
                \n#{@fo_destination.attributes}"
        fo_config = Configuration.configuration['destinations'][@fo_destination_name]
        @retry_after_failing = fo_config[:retry_after_failing] || 60
        @retry_at = Time.now + @retry_after_failing
        SapJCo.log.info "Will attempt to switch back to '#{@destination_name}' in #{@retry_after_failing} seconds."
        SapJCo.log.info "Next attempt to reach destination '#{@destination_name}' at or after #{@retry_at}."
        @active_destination = @fo_destination
        @failed=true
      else
        @active_destination = @original_destination
      end
      @active_destination
    end

    def attempt_reconnection
      if @fo_destination && Time.now > @retry_at
        SapJCo.log.info "Attempting to restablish connection to original destination '#{@destination.name}'."
        begin
          @destination.ping
          SapJCo.log.info "'#{@destination.name}' appears to be availble, reconnecting to:\n#{@destination.attributes}."
          @active_destination = @original_destination
          @failed = false
        rescue Exception => e
          @retry_at = Time.now
          SapJCo.log.warn "'#{@destination.name}' still appears to be unavailable, will retry again at #{@retry_at}.  Error: #{e}"
        end
      end
      @active_destination
    end

    def reset
      @active_destination = @original_destination
    end

    def failover
      @active_destination = @fo_destination
    end
  end


  # Create our own destination provider which converts our YAML config to a
  # java.util.Properties instance that the JCoDestinationManager can use.
  class RubyDestinationDataProvider
    include com.sap.conn.jco.ext.DestinationDataProvider,  SapJCo
    java_import java.util.Properties

    def initialize(configuration)
      @destinations=configuration['destinations']
      if(@destinations)
        SapJCo.log.info "Available SAP app server destinations: #{@destinations.keys.join(', ')}."
      else
        raise "Your configuration appears to be empty or at the very least has no destinations defined."
      end
    end

    def get_destination_properties(destination_name)
      props = Properties.new
      raise "Destination '#{destination_name}' is not defined in your configuration." unless @destinations.include? destination_name.to_s
      @destinations[destination_name.to_s].each do |key, value|
        props.put(key,value)
      end
      props
    end

    def supports_events()
      false
    end

    def set_destination_data_event_listener=(eventListener)

    end
  end
end

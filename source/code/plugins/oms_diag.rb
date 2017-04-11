module OMS
  class Diag

    # Defaults for diagnostic
    DEFAULT_IPNAME = "Diagnostics"
    DEFAULT_TAG    = "diag.oms"

    # Mandatory property keys
    DI_KEY_LOGMESSAGE = 'LogData'
    DI_KEY_IPNAME     = 'IPName'
    DI_KEY_TYPE       = 'type'
    DI_KEY_TIME       = 'time'
    DI_KEY_AGENTGUID  = 'sourceHealthServiceId'

    # Constants for dataitem values
    DI_TYPE_XML   = 'System.PropertyBagData'
    DI_TYPE_JSON  = 'JsonData'

    # Record keys
    RECORD_DATAITEMS  = 'DataItems'
    RECORD_IPNAME     = 'IPName'
    RECORD_MGID       = 'ManagementGroupId'

    # Record constant values
    RECORD_MGID_VALUE = '{00000000-0000-0000-0000-000000000002}'

    class << self

      # Method to be used by INPUT and FILTER plugins for logging

      # Method:
      # LogDiag(logMessage, tag=DEFAULT_TAG)
      #
      # Description:
      # This is to be utilized for logging to the diagnostic
      # channel.
      #
      # Parameters:
      # @logMessage[mandatory]: The log message string to be logged
      # @tag[optional]: The tag with which to emit the diagnostic log. The
      # default value would be DEFAULT_TAG
      # @ipname[optional]: IPName can be optionally provided to depict a
      # customized one other than the DEFAULT_IPNAME in diagnostic event
      # @properties[optional]: Hash corresponding to key value pairs that
      # would be added as part of this data item.
      #
      # NOTE: Certain mandatory properties to the dataitem are added by default
      def LogDiag(logMessage, tag=DEFAULT_TAG, ipname=DEFAULT_IPNAME, properties=nil)
        # Process default values for tag and ipname if they are passed as nil
        tag ||= DEFAULT_TAG
        ipname ||= DEFAULT_IPNAME

        dataitem = Hash.new

        # Adding parameterized properties
        dataitem.merge!(properties) if properties.is_a?(Hash)

        # Adding mandatory properties
        dataitem[DI_KEY_LOGMESSAGE] = logMessage
        dataitem[DI_KEY_IPNAME]     = ipname
        dataitem[DI_KEY_TIME]       = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")

        # Following are expected to be taken care of further processing of dataitem
        # by out_oms_diag
        # 1. Removal of DI_KEY_IPNAME key value pair from dataitem
        # 2. Addition of DI_KEY_AGENTGUID key value pair to dataitem
        # 3. Addition of DI_KEY_TYPE key value pair to dataitem

        # Emitting the record
        Fluent::Engine.emit(tag, Fluent::Engine.now, dataitem)
      end

      # Methods for OUTPUT Plugin (out_oms_diag)

      # Method:
      # ProcessDataItemsPostAggregation(dataitems, agentId)
      #
      # Description:
      # This is utilized by out_oms_diag for altering certain properties
      # to the dataitems before serialization. This method will be
      # called after aggregating dataitems by IPName and before calling
      # serializer.
      #
      # Parameters:
      # @dataitems[mandatory]: Array of dataitems sent via LogDiag from
      # Input and Filter plugins
      # @agentId[mandatory]: The omsagent guid parsed from omsadmin.conf
      def ProcessDataItemsPostAggregation(dataitems, agentId)
        # Remove all invalid dataitems
        dataitems.delete_if{|x| !IsValidDataItem?(x)}
        for x in dataitems
          x.delete(DI_KEY_IPNAME)
          x[DI_KEY_TYPE] = DI_TYPE_JSON
          x[DI_KEY_AGENTGUID] = agentId
        end
      end

      # Method:
      # CreateDiagRecord(dataitems, ipname, optionalAttributes)
      #
      # Description:
      # This is used to create diagnostic record set that is serialized
      # and sent to ODS over HTTPS.
      #
      # Parameters:
      # @dataitems[mandatory]: Array of dataitems that are valid
      # @ipname[mandatory]: The ipname for the record
      # @optionalAttributes[optional]: Key value pairs to be added to
      # the record
      def CreateDiagRecord(dataitems, ipname, optionalAttributes=nil)
        record = Hash.new
        record.merge!(optionalAttributes) if optionalAttributes.is_a?(Hash)
        record[RECORD_DATAITEMS] = dataitems
        record[RECORD_IPNAME] = ipname
        record[RECORD_MGID] = RECORD_MGID_VALUE
        record
      end

      # Private methods

      # Method used to check if dataitem is valid
      def IsValidDataItem?(dataitem)
        if !dataitem.is_a?(Hash) or
           !dataitem.key?(DI_KEY_LOGMESSAGE) or
           !dataitem[DI_KEY_LOGMESSAGE].is_a?(String) or
           !dataitem.key?(DI_KEY_IPNAME) or
           !dataitem[DI_KEY_IPNAME].is_a?(String) or
           !dataitem.key?(DI_KEY_IPNAME) or
           !dataitem[DI_KEY_TIME].is_a?(String)
          return false
        end
        true
      end

    end # class << self
  end # class Diag
end # module OMS

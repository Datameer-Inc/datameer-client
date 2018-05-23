require "datameer_client/version"

# -*- coding: UTF-8 -*-
require 'bundler/setup'

require 'httparty'
require 'uri/common'
require 'cgi/util'
require_relative 'datameer_role_capabilities'

# * Handles all relevant REST calls
# * to use calls containing 'api/' the REST-v2 plugin is necessary
# * Default user is 'admin' but can be changed
# * Also the URL can be changed after initialization
#
# ==Example:
#   client = DatameerClient.new('localhost:8080')
#   client.auth = {username: 'analyst', password: 'analyst'}
#   client.url = 'horst:8080'
class DatameerClient
  include HTTParty
  attr_accessor :url
  attr_accessor :auth

  # @param [String] url Datameer URL
  # @param [String] user Datameer user
  # @param [String] password Datameer users password
  def initialize(url, user, password)
    @url = url
    @auth = {username: user, password: password}
  end

  # Returns a list of all the users and their information including
  # Datameer version, user name, email address, active/inactive, expiration date, group(s), and role(s).
  # @return [HTTParty::Response]
  def get_users
    self.class.get("#{@url}/rest/user-management/users?maxResults=1000", basic_auth: @auth)
  end

  # Creates an internal user in Datameer.
  # @param [String] name
  # @param [String] email
  # @param [String] role
  # @param [String] group can be empty
  # @param [String] password
  # @return [HTTParty::Response]
  def create_user(name,email,role,password,group = nil)
    user_data = {
        :username => name,
        :email => email,
        :groups => [group],
        :roles => [role]

    }
    user_data.delete_if {|key, value| key == :groups && value[0].nil? }
    self.class.post("#{@url}/rest/user-management/users", basic_auth: @auth, body: user_data.to_json, headers: {'Content-Type' => 'application/json'})
    self.class.put("#{@url}/rest/user-management/password/#{URI.escape(name)}", basic_auth: @auth, body: password)
  end

  # Deletes a user from Datameer.
  # @param [String] name Datameer username
  # @return [HTTParty::Response]
  def delete_user(name)
    self.class.delete("#{@url}/rest/user-management/users/#{URI.escape(name)}", basic_auth: @auth)
  end

  # Updates a Datameer user's account.
  # @param [String] name
  # @param [String] changes
  # @return [HTTParty::Response]
  def update_user(name, changes)
    self.class.put("#{@url}/rest/user-management/users/#{URI.escape(name)}", basic_auth: @auth, body: "{#{changes}}")
  end

  # Returns account information about a specific Datameer user.
  # @return [HTTParty::Response]
  def get_user_info
    self.class.get("#{@url}/rest/user-management/logged-in-user?pretty", basic_auth: @auth)
  end

  # Returns a list of all the created group names in Datameer.
  # @return [HTTParty::Response]
  def get_groups
    self.class.get("#{@url}/rest/user-management/groups", basic_auth: @auth)
  end

  # Creates a group in Datameer.
  # @param [String] name group name
  # @return [HTTParty::Response]
  def create_group(name)
    self.class.post("#{@url}/rest/user-management/groups", basic_auth: @auth, body: generate_group_payload(name), headers: {'Content-Type' => 'application/json'})
  end

  # Creates a group in Datameer.
  # @param [String] name group name
  # @param [String] new_name new group name
  # @return [HTTParty::Response]
  def update_group(name, new_name)
    self.class.put("#{@url}/rest/user-management/groups/#{URI.escape(name)}", basic_auth: @auth, body: generate_group_payload(new_name), headers: {'Content-Type' => 'application/json'})
  end

  # Deletes a group in Datameer.
  # @param [String] name group name
  # @return [HTTParty::Response]
  def delete_group(name)
    self.class.delete("#{@url}/rest/user-management/groups/#{URI.escape(name)}", basic_auth: @auth)
  end

  # Returns a list of all the created role names in Datameer.
  # @return [HTTParty::Response]
  def get_roles
    self.class.get("#{@url}/rest/user-management/roles", basic_auth: @auth)
  end

  # Creates a role in Datameer.
  # @param [String] name Role name
  # @param [Array<String>] capabilities capability name list
  # @return [HTTParty::Response]
  def create_role(name, capabilities = DatameerRoleCapabilities.get_common_capabilities)
    self.class.post("#{@url}/rest/user-management/roles", basic_auth: @auth, body: generate_role_payload(name,capabilities), headers: {'Content-Type' => 'application/json'})
  end

  # Updates a role in Datameer.
  # @param [String] name Role name
  # @param [String] new_name new role name
  # @param [Array<String>] capabilities capability name list
  # @return [HTTParty::Response]
  def update_role(name, new_name = name, capabilities)
    self.class.put("#{@url}/rest/user-management/roles/#{URI.escape(name)}", basic_auth: @auth, body: generate_role_payload(new_name,capabilities), headers: {'Content-Type' => 'application/json'})
  end

  # Deletes a role in Datameer.
  # @param [String] name Role name
  # @return [HTTParty::Response]
  def delete_role(name)
    self.class.delete("#{@url}/rest/user-management/roles/#{URI.escape(name)}", basic_auth: @auth)
  end

  # *** file system operations ***

  # Creates an empty folder in Datameer.
  # @param [String] folder_name folder name
  # @param [Integer] parent_folder_id parent folder entity id OR uuid OR path
  # @return [HTTParty::Response]
  def create_folder(folder_name,parent_folder_id)
    self.class.post("#{url}/api/filesystem/folders/#{ERB::Util.url_encode(parent_folder_id)}", basic_auth: @auth, body: {:name => folder_name}.to_json, headers: {'Content-Type' => 'application/json'})
  end

  # Renames a folder in Datameer.
  # @param [Integer] id folder entity id
  # @param [String] folder_name folder name
  # @return [HTTParty::Response]
  def rename_folder(id,folder_name)
    self.class.put("#{url}/api/filesystem/folders/#{ERB::Util.url_encode(id)}/name", basic_auth: @auth, body: {:name => folder_name}.to_json, headers: {'Content-Type' => 'application/json'})
  end

  # Moves a folder in Datameer.
  # @param [Integer] id folder entity id
  # @param [String, Integer] parent_folder the parent folders path OR entity_id OR uuid
  # @return [HTTParty::Response]
  def move_folder(id,parent_folder)
    self.class.put("#{url}/api/filesystem/folders/#{ERB::Util.url_encode(id)}/parent", basic_auth: @auth,body: {'parentFolder' => parent_folder}.to_json, headers: {'Content-Type' => 'application/json'})
  end

  # Deletes an empty folder in Datameer.
  # @param [Integer] id folder entity id
  # @return [HTTParty::Response]
  def delete_folder(id)
    self.class.delete("#{url}/api/filesystem/folders/#{ERB::Util.url_encode(id)}", basic_auth: @auth)
  end

  # Creates a backup of a folder
  # @param [String, Integer] folder folders entity id OR uuid OR path
  # @param [Array] options optional parameters to backup owner reference, group sharing or permissions
  # @return [HTTParty::Response]
  def backup_folder(folder, options = [])
    self.class.get("#{url}/api/filesystem/folders/#{ERB::Util.url_encode(folder)}/backup#{transform_backup_options(options)}", basic_auth: @auth)
  end

  # Restores a folder based on a zip
  # @param [String, Integer] parent_folder folders entity id OR uuid OR path
  # @param [String] folder_zip backup zip of a folder and its content
  # @return [HTTParty::Response]
  def restore_folder(folder_zip, parent_folder, options = [])
    self.class.put("#{url}/api/filesystem/folders/#{ERB::Util.url_encode(parent_folder)}/restore#{transform_backup_options(options)}", basic_auth: @auth, body: folder_zip, headers: {'Content-Type' => 'application/zip'})
  end

  # Transforms a comma separated list of options for advanced usage of folder backup or restore in valid URL parameters
  # @param [String] options the options as comma separated list of keywords
  # @return [String]
  def transform_backup_options(options)
    unless options.nil? || options.size == 0
      option_params = []
      options = options.split(',')
      options.each do |option|
        if (option =~ /^group/i) != nil
          option_params << '&includeGroupPermissions'
        elsif (option =~ /^owner/i) != nil
          option_params << '&includeOwner'
        elsif (option =~ /^substitute/i) != nil
          option_params << '&substituteMissingUser'
        elsif (option =~ /^sharing/i) != nil
          option_params << '&includeSharing'
        elsif (option =~ /^overwrite/i) != nil
          option_params << '&overwrite'
        elsif (option =~ /^ignore_groups/i) != nil
          option_params << '&ignoreUnknownGroups'
        elsif (option =~ /^data/i) != nil
          option_params << '&includeDataPermissions'
        elsif (option =~ /^ignore_dependencies/i) != nil
          option_params << '&ignoreMissingDependencies'
        elsif (option =~ /^skip/i) != nil
          option_params << '&skipFilesWithMissingDependencies'
        end
      end
      option_params.sort!
      option_params = option_params.join
      option_params[0] = '?'
      option_params
    end
  end

  # *** entity management ***

  # *** import jobs ***

  def get_import_job(id)
    self.class.get("#{@url}/rest/import-job/#{id}", basic_auth: @auth)
  end

  def get_import_jobs
    self.class.get("#{@url}/rest/import-job", basic_auth: @auth)
  end

  def get_import_job_dependencies(id ,direction=nil ,level=nil)
    self.class.get("#{@url}/api/import-job/#{id}/dependencies?direction=#{direction}&level=#{level}", basic_auth: @auth)
  end

  def get_import_job_metadata(id)
    self.class.get("#{@url}/rest/data/import-job/#{id}", basic_auth: @auth)
  end

  def create_import_job(data)
    self.class.post("#{@url}/rest/import-job", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def update_import_job(data, id)
    self.class.put("#{@url}/rest/import-job/#{id}", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def delete_import_job(id)
    self.class.delete("#{@url}/rest/import-job/#{id}", basic_auth: @auth)
  end

  # *** workbooks ***

  def get_workbook(id)
    warn "[DEPRECATION] `get_workbook` is deprecated. Please use `get_workbook_v2` instead"
    self.class.get("#{@url}/rest/workbook/#{id}", basic_auth: @auth)
  end

  def get_workbook_v2(uuid)
    self.class.get("#{@url}/api/workbooks/#{uuid}", basic_auth: @auth)
  end

  def get_workbooks
    self.class.get("#{@url}/rest/workbook", basic_auth: @auth)
  end

  def get_workbook_dependencies(id ,direction=nil ,level=nil)
    self.class.get("#{@url}/api/workbook/#{id}/dependencies?direction=#{direction}&level=#{level}", basic_auth: @auth)
  end

  def get_workbook_metadata(id)
    self.class.get("#{@url}/rest/data/workbook/#{id}", basic_auth: @auth)
  end

  def delete_workbook(id)
    self.class.delete("#{@url}/rest/workbook/#{id}", basic_auth: @auth)
  end

  def create_workbook(data)
    warn "[DEPRECATION] `create_workbook` is deprecated. Please use `create_workbook_v2` instead"
    self.class.post("#{@url}/rest/workbook", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def create_workbook_v2(data)
    self.class.post("#{@url}/api/workbooks", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def update_workbook(data, id)
    self.class.put("#{@url}/rest/workbook/#{id}", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def update_workbook_v2(data, uuid)
    self.class.put("#{@url}/api/workbooks/#{uuid}", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def rollback_workbook(data)
    self.class.put("#{@url}/api/workbooks/rollback", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  # ** exportjobs ***

  def get_export_job(id)
    self.class.get("#{@url}/rest/export-jobs/#{id}", basic_auth: @auth)
  end

  def get_export_job_dependencies(id ,direction=nil ,level=nil)
    self.class.get("#{@url}/api/export-job/#{id}/dependencies?direction=#{direction}&level=#{level}", basic_auth: @auth)
  end

  def get_export_jobs
    self.class.get("#{@url}/rest/export-jobs", basic_auth: @auth)
  end

  def create_export_job(data)
    self.class.post("#{@url}/rest/export-jobs", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def update_export_job(data, id)
    self.class.put("#{@url}/rest/export-job/#{id}", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def delete_export_job(id)
    self.class.delete("#{@url}/rest/export-job/#{id}", basic_auth: @auth)
  end

  # *** connections ***

  def create_connection(data)
    self.class.post("#{@url}/rest/connections", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def get_connections
    self.class.get("#{@url}/rest/connections", basic_auth: @auth)
  end

  def get_connection_dependencies(id ,direction=nil ,level=nil)
    self.class.get("#{@url}/api/connections/#{id}/dependencies?direction=#{direction}&level=#{level}", basic_auth: @auth)
  end

  def get_connection(id)
    self.class.get("#{@url}/rest/connections/#{id}", basic_auth: @auth)
  end

  def update_connection(data, id)
    self.class.put("#{@url}/rest/connections/#{id}", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def delete_connection(id)
    self.class.delete("#{@url}/rest/connections/#{id}", basic_auth: @auth)
  end

  # *** infographics ***

  def create_infographic(data)
    self.class.post("#{@url}/rest/infographics", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def update_infographic(data, id)
    self.class.put("#{@url}/rest/infographics/#{id}", basic_auth: @auth, body: data, headers: {'Content-Type' => 'application/json'})
  end

  def get_infographics
    self.class.get("#{@url}/rest/infographics", basic_auth: @auth)
  end

  def get_infographic(id)
    self.class.get("#{@url}/rest/infographics/#{id}", basic_auth: @auth)
  end

  def get_infographic_dependencies(id ,direction=nil ,level=nil)
    self.class.get("#{@url}/api/infographics/#{id}/dependencies?direction=#{direction}&level=#{level}", basic_auth: @auth)
  end

  def delete_infographic(id)
    self.class.delete("#{@url}/rest/infographics/#{id}", basic_auth: @auth)
  end

  # *** job trigger ***

  def run_datameer_job(id)
    self.class.post("#{@url}/rest/job-execution?configuration=#{id}", basic_auth: @auth)
  end

  def kill_job(id)
    self.class.post("#{@url}/rest/job-execution/job-kill/#{id}", basic_auth: @auth)
  end

  # *** misc ***

  def get_sheet_details_by_id(id,sheet_name = nil)
    self.class.get("#{@url}/rest/sheet-details/#{id}/#{sheet_name}", basic_auth: @auth)
  end

  def get_sheet_details_by_filepath(path,sheet_name = nil)
    if sheet_name != nil
      sheet_name = "&sheetName=#{CGI.escape(sheet_name)}"
    else
      sheet_name = sheet_name
    end
    self.class.get("#{@url}/rest/sheet-details?file=#{path}#{sheet_name}", basic_auth: @auth)
  end

  def get_volume_report(id)
    self.class.get("#{@url}/rest/job-configuration/volume-report/#{id}", basic_auth: @auth)
  end

  def get_system_info
    self.class.get("#{@url}/rest/license-details", basic_auth: @auth)
  end

  def get_product_id
    self.class.get("#{@url}/license/product-id", basic_auth: @auth)
  end

  def get_running_jobs
    self.class.get("#{@url}/rest/jobs/list-running", basic_auth: @auth)
  end

  def get_running_jobs_ui
    self.class.get("#{@url}/admin/system-overview/runningJobs", basic_auth: @auth)
  end

  def generate_group_payload(name)
    generate_payload = {:name => name}.to_json
  end

  def generate_role_payload(name, caps)
    payload = {:name => name, :capabilities => caps}.to_json
  end

  def get_job_status(id)
    self.class.get("#{@url}/rest/job-configuration/job-status/#{id}", basic_auth: @auth)
  end

  def get_job_history(id,start,length)
    self.class.get("#{@url}/rest/job-configuration/job-history/#{id}?start=#{start}&length=#{length}", basic_auth: @auth)
  end

  def get_job_details(exec_id)
    self.class.get("#{@url}/rest/job-execution/job-details/#{exec_id}", basic_auth: @auth)
  end

  def download_wbk_data(id, sheet_name)
    self.class.get("#{@url}/rest/data/workbook/#{id}/#{sheet_name}/download", basic_auth: @auth)
  end

  def download_job_data(id)
    self.class.get("#{@url}/rest/data/import-job/#{id}/download", basic_auth: @auth)
  end

  def delete_job_data(exec_id)
    self.class.delete("#{@url}/rest/data/#{exec_id}", basic_auth: @auth)
  end

  def delete_file(file_id)
    self.class.delete("#{@url}/api/filesystem/files?fileIds=#{file_id}", basic_auth: @auth)
  end

  def set_tag(file_id, tags)
    self.class.put("#{@url}/api/filesystem/files/#{file_id}/command", basic_auth: @auth, body: "{_type: SetTags, tags:[#{tags}]}", headers: {'Content-Type' => 'application/json'})
  end

  # ********************************
  # *** Permission and Ownership ***

  def get_root_folder
    self.class.get("#{@url}/api/filesystem/root-folder", basic_auth: @auth)
  end

  def read_folder(id)
    self.class.get("#{@url}/api/filesystem/folders/#{id}", basic_auth: @auth)
  end

  def read_file(id)
    self.class.get("#{@url}/api/filesystem/files/#{id}", basic_auth: @auth)
  end

  # *** possible values for:
  # ** type => folder, file
  # ** target => group, others, owner
  def get_permissions_for(type,id,target = nil)
    self.class.get("#{@url}/api/filesystem/#{type}s/#{id}/permission/#{target}", basic_auth: @auth)
  end

  def change_owner_of_folder(id,owner)
    self.class.put("#{@url}/api/filesystem/folders/#{id}/permission/owner", basic_auth: @auth, body: "{owner:#{owner}}", headers: {'Content-Type' => 'application/json'})
  end

  def create_group_permission_for_folder(id,body)
    self.class.post("#{@url}/api/filesystem/folders/#{id}/permission/groups", basic_auth: @auth, body: "{#{body}}", headers: {'Content-Type' => 'application/json'})
  end

  def update_group_permission_for_folder(id,group,body)
    self.class.put("#{@url}/api/filesystem/folders/#{id}/permission/groups/#{group}", basic_auth: @auth, body: "{#{body}}", headers: {'Content-Type' => 'application/json'})
  end

  def update_others_permission_for_folder(id,body)
    self.class.put("#{@url}/api/filesystem/folders/#{id}/permission/others", basic_auth: @auth, body: "{#{body}}", headers: {'Content-Type' => 'application/json'})
  end

  def delete_group_permission_for_folder(id,group)
    self.class.delete("#{@url}/api/filesystem/folders/#{id}/permission/groups/#{group}", basic_auth: @auth, headers: {'Content-Type' => 'application/json'})
  end

  def change_owner_of_file(id,owner)
    self.class.put("#{@url}/api/filesystem/files/#{id}/permission/owner", basic_auth: @auth, body: "{owner:#{owner}}", headers: {'Content-Type' => 'application/json'})
  end

  def create_group_permission_for_file(id,body)
    self.class.post("#{@url}/api/filesystem/files/#{id}/permission/groups", basic_auth: @auth, body: "{#{body}}", headers: {'Content-Type' => 'application/json'})
  end

  def update_group_permission_for_file(id,group,body)
    self.class.put("#{@url}/api/filesystem/files/#{id}/permission/groups/#{group}", basic_auth: @auth, body: "{#{body}}", headers: {'Content-Type' => 'application/json'})
  end

  def update_others_permission_for_file(id,body)
    self.class.put("#{@url}/api/filesystem/files/#{id}/permission/others", basic_auth: @auth, body: "{#{body}}", headers: {'Content-Type' => 'application/json'})
  end

  def delete_group_permission_for_file(id,group)
    self.class.delete("#{@url}/api/filesystem/files/#{id}/permission/groups/#{group}", basic_auth: @auth, headers: {'Content-Type' => 'application/json'})
  end

  def get_api_object(href)
    self.class.get("#{@url}#{href}", basic_auth: @auth)
  end

  def get_conductor_log
    res = self.class.get("#{@url}/admin/application-log-download", basic_auth: @auth)
    self.class.get("#{@url}/j_spring_security_logout", headers: {'Cookie' => res.headers['Set-Cookie'] })
    res
  end

  def get_entity_job(entity_id)
    self.class.get("#{@url}/rest/job-configuration/job-status/#{entity_id}", basic_auth: @auth)
  end

  def get_job_log(job_execution_id)
    res = self.class.get("#{@url}/file-job?jobExecutionId=#{job_execution_id}", basic_auth: @auth)
    self.class.get("#{@url}/j_spring_security_logout", headers: {'Cookie' => res.headers['Set-Cookie'] })
    res
  end

  def get_job_trace(job_execution_id)
    res = self.class.get("#{@url}/job/download-trace/#{job_execution_id}", basic_auth: @auth)
    self.class.get("#{@url}/j_spring_security_logout", headers: {'Cookie' => res.headers['Set-Cookie'] })
    res
  end
end

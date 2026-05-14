# ==========================================
# APPSTORE MANAGEMENT FASTFILE
# ==========================================
# This file contains all App Store Connect management lanes for the iOS app
# It handles creating new version entries, managing metadata, and other
# App Store Connect operations that don't involve binary uploads
#
# Import this file in your main Fastfile with:
# import 'Fastfile.appstore.rb'

platform :ios do
  # ==========================================
  # CREATE OR UPDATE APP STORE VERSION ENTRY
  # ==========================================
  desc "Create or update App Store version entry without uploading binary"
  lane :create_app_store_version do |options|
    version = options[:version]
    platform = options[:platform] || "iOS"

    UI.message("🚀 Creating or updating App Store version entry")
    UI.message("📱 Platform: #{platform}")
    UI.message("🔢 Version: #{version}")
    UI.message("📱 App ID: #{ENV["BUNDLE_ID"]}")

    # ==========================================
    # CONFIGURE APP STORE CONNECT API
    # ==========================================
    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    # ==========================================
    # CREATE OR UPDATE VERSION ENTRY
    # ==========================================
    begin
      deliver(
        app_identifier: ENV["BUNDLE_ID"],
        app_version: version,
        skip_binary_upload: true,
        skip_screenshots: true,
        skip_metadata: true,
        force: true,
        phased_release: true,
        precheck_include_in_app_purchases: false,
        run_precheck_before_submit: false,
        submit_for_review: false,
        overwrite_screenshots: false
      )

      UI.success("✅ Successfully created or updated version #{version} in App Store Connect!")

      {
        success: true,
        version: version,
        platform: platform,
        action: "created_or_updated",
        message: "Version created or updated successfully"
      }

    rescue => e
      UI.error("❌ Failed to create or update version: #{e.message}")
      {
        success: false,
        version: version,
        platform: platform,
        error: e.message,
        message: "Failed to create or update version"
      }
    end
  end

  # ==========================================
  # WRITE APP STORE RELEASE NOTES
  # ==========================================
  desc "Write release notes to App Store Connect for all supported locales"
  lane :write_app_store_release_notes do |options|
    version = options[:version]
    platform = options[:platform] || "iOS"
    english_notes = options[:english_notes]

    UI.message("📝 Updating App Store Connect release notes")
    UI.message("📱 Platform: #{platform}")
    UI.message("🔢 Version: #{version}")
    UI.message("📱 App ID: #{ENV["BUNDLE_ID"]}")

    # ==========================================
    # CONFIGURE APP STORE CONNECT API
    # ==========================================
    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    # ==========================================
    # UPDATE RELEASE NOTES
    # ==========================================
    begin
      release_notes_hash = {
        "en-US" => english_notes
      }

      release_notes_hash.each do |locale, notes|
        UI.message("📝 #{locale}: #{notes[0..50]}...")
      end

      deliver(
        app_identifier: ENV["BUNDLE_ID"],
        app_version: version,
        skip_binary_upload: true,
        skip_screenshots: true,
        skip_metadata: false,
        edit_live: false,
        force: true,
        phased_release: true,
        precheck_include_in_app_purchases: false,
        run_precheck_before_submit: false,
        submit_for_review: false,
        release_notes: release_notes_hash
      )

      UI.success("✅ Successfully updated release notes for version #{version} in App Store Connect!")

      {
        success: true,
        version: version,
        platform: platform,
        message: "Release notes updated successfully"
      }

    rescue => e
      UI.error("❌ Failed to update release notes: #{e.message}")
      {
        success: false,
        version: version,
        platform: platform,
        error: e.message,
        message: "Failed to update release notes"
      }
    end
  end

  # ==========================================
  # UPLOAD APP STORE METADATA (description, keywords, etc.)
  # ==========================================
  desc "Upload App Store metadata from fastlane/metadata (all locales) for a version"
  lane :upload_app_store_metadata do |options|
    version = options[:version]
    platform = options[:platform] || "iOS"

    UI.header("📤 Uploading App Store metadata for v#{version}")
    UI.message("📱 Platform: #{platform}")

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    review_info = {
      first_name: "Leonardo",
      last_name: "Cardoso",
      email_address: ENV["BETA_CONTACT_EMAIL"],
      phone_number: ENV["BETA_CONTACT_PHONE"],
      demo_user: "",
      demo_password: "",
      notes: File.read(File.expand_path("metadata/review_information/notes.txt", __dir__)).strip
    }

    missing = [:email_address, :phone_number].select { |k| review_info[k].nil? || review_info[k].empty? }
    UI.user_error!("Missing env vars: #{missing.map { |k| k == :email_address ? 'BETA_CONTACT_EMAIL' : 'BETA_CONTACT_PHONE' }.join(', ')}") unless missing.empty?

    begin
      deliver(
        app_identifier: ENV["BUNDLE_ID"],
        app_version: version,
        skip_binary_upload: true,
        skip_screenshots: true,
        skip_metadata: false,
        edit_live: false,
        force: true,
        phased_release: true,
        precheck_include_in_app_purchases: false,
        run_precheck_before_submit: false,
        submit_for_review: false,
        app_review_information: review_info
      )

      UI.success("✅ Metadata uploaded for v#{version}")

      {
        success: true,
        version: version,
        platform: platform,
        message: "Metadata uploaded successfully"
      }
    rescue => e
      UI.error("❌ Failed to upload metadata: #{e.message}")
      {
        success: false,
        version: version,
        platform: platform,
        error: e.message,
        message: "Failed to upload metadata"
      }
    end
  end

  # ==========================================
  # ADD BUILD TO APP STORE RELEASE
  # ==========================================
  desc "Add build to App Store release and optionally submit for review"
  lane :add_build_to_release do |options|
    version = options[:version]
    build_number = options[:build_number]
    platform = options[:platform] || "iOS"
    submit_for_review = options[:submit_for_review] != false

    UI.message("🚀 Adding build to App Store release")
    UI.message("📱 Platform: #{platform}")
    UI.message("🔢 Version: #{version || '(will get current App Store version entry)'}")
    UI.message("🏗️ Build number: #{build_number || '(will get latest from TestFlight)'}")
    UI.message("📋 Submit for review: #{submit_for_review ? 'Yes' : 'No'}")
    UI.message("📱 App ID: #{ENV["BUNDLE_ID"]}")

    # ==========================================
    # CONFIGURE APP STORE CONNECT API
    # ==========================================
    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    # ==========================================
    # GET CURRENT APP STORE VERSION IF NOT PROVIDED
    # ==========================================
    if version.nil? || version.empty?
      UI.message("🔍 Getting current App Store version entry...")
      begin
        require 'spaceship'

        app = Spaceship::ConnectAPI::App.find(ENV["BUNDLE_ID"])
        raise "App not found in App Store Connect" if app.nil?

        edit_version = app.get_edit_app_store_version
        if edit_version
          version = edit_version.version_string
          UI.success("✅ Found current App Store version entry: #{version}")
        else
          raise "No editable App Store version found"
        end
      rescue => e
        UI.error("❌ Failed to get App Store version: #{e.message}")
        raise e
      end
    end

    # ==========================================
    # GET LATEST BUILD IF NOT PROVIDED
    # ==========================================
    if build_number.nil? || build_number.empty?
      UI.message("🔍 Getting latest build from TestFlight...")
      begin
        latest_build_info = latest_testflight_build_number(
          app_identifier: ENV["BUNDLE_ID"],
          platform: platform.downcase
        )
        build_number = latest_build_info.to_s
        UI.success("✅ Latest TestFlight build: #{build_number}")
      rescue => e
        UI.error("❌ Failed to get latest build: #{e.message}")
        raise e
      end
    end

    # ==========================================
    # ADD BUILD TO RELEASE
    # ==========================================
    begin
      require 'spaceship'

      app = Spaceship::ConnectAPI::App.find(ENV["BUNDLE_ID"])
      raise "App not found" if app.nil?

      app_store_version = app.get_edit_app_store_version
      raise "App Store version not found" if app_store_version.nil?

      if app_store_version.version_string != version
        raise "Version mismatch: Expected #{version}, found #{app_store_version.version_string}"
      end

      # Find the build
      builds = app.get_builds(
        filter: { version: build_number },
        includes: "preReleaseVersion"
      )
      raise "Build #{build_number} not found in TestFlight" if builds.empty?

      build = builds.first
      UI.success("✅ Found build: #{build.version} (#{build.uploaded_date})")

      # Select the build for the App Store version
      app_store_version.select_build(build_id: build.id)
      UI.success("✅ Successfully added build #{build_number} to version #{version}")

      # ==========================================
      # SUBMIT FOR REVIEW IF REQUESTED
      # ==========================================
      if submit_for_review
        begin
          app_store_version = app.get_edit_app_store_version

          if ["READY_FOR_SALE", "IN_REVIEW"].include?(app_store_version.app_store_state)
            UI.message("⚠️ Version #{version} is already #{app_store_version.app_store_state}")
          elsif app_store_version.app_store_state != "PREPARE_FOR_SUBMISSION"
            UI.message("⚠️ Version #{version} is in state: #{app_store_version.app_store_state}")
          else
            UI.message("🚀 Using deliver submit_build to submit for App Store review...")

            deliver(
              app_identifier: ENV["BUNDLE_ID"],
              build_number: build_number,
              submit_for_review: true,
              force: true,
              skip_metadata: true,
              skip_screenshots: true,
              skip_binary_upload: true,
              automatic_release: false,
              phased_release: true,
              precheck_include_in_app_purchases: false,
              run_precheck_before_submit: false
            )

            refreshed_version = app.get_edit_app_store_version
            UI.success("✅ Successfully submitted version #{version} to App Store review! (state: #{refreshed_version&.app_store_state})")
          end
        rescue => e
          UI.error("❌ Failed to submit for review: #{e.message}")
          raise e
        end
      end

      {
        success: true,
        version: version,
        build_number: build_number,
        platform: platform,
        submitted_for_review: submit_for_review,
        message: submit_for_review ? "Build added and submitted for review" : "Build added successfully"
      }

    rescue => e
      UI.error("❌ Failed to add build to release: #{e.message}")
      {
        success: false,
        version: version,
        build_number: build_number,
        platform: platform,
        error: e.message,
        message: "Failed to add build to release"
      }
    end
  end

  # ==========================================
  # VALIDATE APP STORE VERSION FOR RELEASE
  # ==========================================
  desc "Validate that App Store version is ready for release"
  lane :validate_app_store_version_for_release do |options|
    version = options[:version]
    platform = options[:platform] || "iOS"

    UI.message("🔍 Validating App Store version for release")
    UI.message("📱 App ID: #{ENV["BUNDLE_ID"]}")

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    begin
      require 'spaceship'

      app = Spaceship::ConnectAPI::App.find(ENV["BUNDLE_ID"])
      raise "App not found" if app.nil?

      app_store_versions = app.get_app_store_versions(
        filter: { appStoreState: "PENDING_DEVELOPER_RELEASE,READY_FOR_SALE,IN_REVIEW,WAITING_FOR_REVIEW,DEVELOPER_REJECTED,REJECTED,PREPARE_FOR_SUBMISSION" }
      )

      target_version = app_store_versions.find { |v| v.version_string == version }
      raise "Version #{version} not found in App Store Connect" if target_version.nil?

      if target_version.app_store_state == "PENDING_DEVELOPER_RELEASE"
        UI.success("✅ Version #{version} is ready for release!")
        {
          success: true,
          version: version,
          platform: platform,
          state: target_version.app_store_state,
          message: "Version is ready for release"
        }
      else
        UI.error("❌ Version #{version} is not ready for release (state: #{target_version.app_store_state})")
        raise "Version not ready for release"
      end

    rescue => e
      UI.error("❌ Failed to validate version: #{e.message}")
      {
        success: false,
        version: version,
        platform: platform,
        error: e.message,
        message: "Failed to validate version for release"
      }
    end
  end

  # ==========================================
  # RELEASE APP TO APP STORE
  # ==========================================
  desc "Release app version to App Store with phased release and scheduling options"
  lane :release_app_to_store do |options|
    version = options[:version]
    platform = options[:platform] || "iOS"
    phased_release = options[:phased_release] == "true" || options[:phased_release] == true

    UI.message("🚀 Releasing app to App Store")
    UI.message("📱 App ID: #{ENV["BUNDLE_ID"]}")
    UI.message("🔢 Version: #{version}")
    UI.message("📊 Phased Release: #{phased_release ? 'Yes' : 'No'}")

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    begin
      require 'spaceship'

      app = Spaceship::ConnectAPI::App.find(ENV["BUNDLE_ID"])
      raise "App not found" if app.nil?

      app_store_versions = app.get_app_store_versions(
        filter: { appStoreState: "PENDING_DEVELOPER_RELEASE" }
      )

      target_version = app_store_versions.find { |v| v.version_string == version }
      raise "Version #{version} not found in PENDING_DEVELOPER_RELEASE state" if target_version.nil?

      if phased_release
        begin
          target_version.create_app_store_version_phased_release
          UI.message("✅ Phased release enabled successfully")
        rescue => e
          UI.message("⚠️ Could not create phased release: #{e.message}")
        end
      end

      target_version.create_app_store_version_release_request
      UI.success("✅ Successfully released version #{version} to App Store!")

      {
        success: true,
        version: version,
        platform: platform,
        phased_release: phased_release,
        message: "Successfully released app to App Store"
      }

    rescue => e
      UI.error("❌ Failed to release app: #{e.message}")
      {
        success: false,
        version: version,
        platform: platform,
        error: e.message,
        message: "Failed to release app to App Store"
      }
    end
  end

  # ==========================================
  # FIND VERSION READY FOR RELEASE
  # ==========================================
  desc "Find version that is ready for release (in PENDING_DEVELOPER_RELEASE state)"
  lane :find_version_ready_for_release do |options|
    platform = options[:platform] || "iOS"

    UI.message("🔍 Finding version ready for release")
    UI.message("📱 App ID: #{ENV["BUNDLE_ID"]}")

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    begin
      require 'spaceship'

      app = Spaceship::ConnectAPI::App.find(ENV["BUNDLE_ID"])
      raise "App not found" if app.nil?

      app_store_versions = app.get_app_store_versions(
        filter: { appStoreState: "PENDING_DEVELOPER_RELEASE" }
      )

      raise "No versions ready for release" if app_store_versions.empty?

      ready_version = app_store_versions.sort_by { |v| v.created_date }.reverse.first

      UI.success("✅ Found version ready for release: #{ready_version.version_string}")

      {
        success: true,
        version: ready_version.version_string,
        platform: platform,
        state: ready_version.app_store_state,
        message: "Found version ready for release"
      }

    rescue => e
      UI.error("❌ Failed to find version ready for release: #{e.message}")
      raise e
    end
  end
end

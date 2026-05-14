# ==========================================
# DELIVERY FASTFILE
# ==========================================
# This file contains all delivery-related lanes for the iOS app
# It handles building, testing, and uploading to TestFlight
#
# Import this file in your main Fastfile with:
# import 'Fastfile.delivery.rb'

platform :ios do
  # ==========================================
  # MAIN DELIVERY LANE
  # ==========================================
  # This lane handles the complete delivery process:
  # 1. Builds the app with Release configuration
  # 2. Uploads to TestFlight
  # 3. Distributes to selected test groups
  # 4. Submits for TestFlight review
  desc "Build and deliver to TestFlight"
  lane :deliver_to_testflight do |options|
    # ==========================================
    # STEP 1: PREPARE BUILD CONFIGURATION
    # ==========================================
    scheme = options[:scheme] || ENV["APP_NAME"]

    # Parse test groups from comma-separated string
    # Default: Reviewers beta group (fa083db9-5a14-4986-9f92-5e5abdcdfb5b)
    all_test_groups = options[:groups] ? options[:groups].split(",").map(&:strip) : ["fa083db9-5a14-4986-9f92-5e5abdcdfb5b"]

    # Filter out "Internal Testers" since they're automatically assigned to all builds
    test_groups = all_test_groups.reject { |group| group == "Internal Testers" }

    # Check if Internal Testers was requested (for logging purposes)
    includes_internal = all_test_groups.include?("Internal Testers")

    if includes_internal && test_groups.empty?
      UI.message("📝 Only Internal Testers requested - they're automatically assigned to all builds")
    elsif includes_internal
      UI.message("📝 Internal Testers will be automatically assigned (not explicitly added to groups)")
    end

    # Get release notes from options or create default
    custom_release_notes = options[:release_notes]

    UI.message("🚀 Starting TestFlight delivery")
    UI.message("📱 Scheme: #{scheme}")
    UI.message("👥 Test Groups: #{test_groups.join(', ')}")
    UI.message("📝 Release Notes: #{custom_release_notes ? 'Custom provided' : 'Will generate default'}")

    # ==========================================
    # STEP 2: CONFIGURE APP STORE CONNECT
    # ==========================================
    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    # ==========================================
    # STEP 3: SETUP TEMPORARY KEYCHAIN
    # ==========================================
    UI.message("🔐 Setting up temporary keychain for CI...")

    keychain_name = "fastlane_tmp_keychain"
    keychain_password = SecureRandom.hex

    delete_keychain(
      name: keychain_name
    ) rescue nil

    create_keychain(
      name: keychain_name,
      password: keychain_password,
      default_keychain: false,
      unlock: true,
      timeout: 3600,
      lock_when_sleeps: false,
      add_to_search_list: true
    )

    # ==========================================
    # STEP 4: SYNC CODE SIGNING
    # ==========================================
    UI.message("🔐 Syncing code signing certificates...")

    match(
      type: "appstore",
      app_identifier: ENV["BUNDLE_ID"],
      keychain_name: keychain_name,
      keychain_password: keychain_password,
      force: true,
      include_all_certificates: true,
      verbose: true
    )

    # ==========================================
    # STEP 5: BUILD THE APP
    # ==========================================
    UI.message("🔨 Building app for distribution...")

    begin
      gym(
        project: "#{ENV["APP_NAME"]}.xcodeproj",
        scheme: scheme,
        clean: true,
        output_directory: "./build",
        output_name: "#{ENV["APP_NAME"]}.ipa",
        export_method: "app-store",
        export_options: {
          provisioningProfiles: {
            ENV["BUNDLE_ID"] => "match AppStore #{ENV["BUNDLE_ID"]}"
          }
        },
        xcargs: "-allowProvisioningUpdates",
        suppress_xcode_output: false,
        disable_xcpretty: false,
        buildlog_path: "./logs",
        verbose: true
      )
    rescue => ex
      UI.error("Build failed with error: #{ex.message}")

      log_files = Dir.glob("./logs/**/*.log")
      if log_files.any?
        UI.important("🔍 Build log contents:")
        log_files.each do |log_file|
          begin
            log_content = File.read(log_file)
            lines = log_content.split("\n")
            relevant_lines = lines.last(50)
            relevant_lines.each { |line| UI.message("  #{line}") }
          rescue => log_ex
            UI.error("Could not read log file #{log_file}: #{log_ex.message}")
          end
        end
      end

      raise ex
    end

    UI.success("✅ Build completed successfully!")

    # ==========================================
    # STEP 6: UPLOAD TO TESTFLIGHT
    # ==========================================
    UI.message("📤 Uploading to TestFlight...")

    ipa_path = lane_context[SharedValues::IPA_OUTPUT_PATH]

    # Read version info for changelog
    xcconfig_path = (ENV["XCCONFIG_PATH"] || "#{ENV["APP_NAME"]}/Config/Base.xcconfig")
    marketing_version = get_xcconfig_value(
      path: xcconfig_path,
      name: "MARKETING_VERSION"
    )
    build_number = get_xcconfig_value(
      path: xcconfig_path,
      name: "CURRENT_PROJECT_VERSION"
    )

    # Get latest TestFlight version to compare
    UI.message("🔍 Checking TestFlight for existing versions...")
    should_submit_for_review = true

    begin
      latest_tf_build_number = latest_testflight_build_number(
        api_key: api_key,
        app_identifier: ENV["BUNDLE_ID"],
        version: marketing_version
      )

      if build_number.to_i <= latest_tf_build_number.to_i
        should_submit_for_review = false
        UI.message("⚠️ Same or older build number detected - skipping beta review submission")
      else
        UI.message("✅ New build number detected - will submit for beta review")
      end
    rescue => e
      UI.message("⚠️ Could not get TestFlight build info: #{e.message}")
      should_submit_for_review = true
    end

    # Create changelog
    if custom_release_notes && !custom_release_notes.empty?
      changelog = "Version #{marketing_version} (#{build_number})\n\n#{custom_release_notes}"
    else
      changelog = "Version #{marketing_version} (#{build_number})\n\n"

      is_production = ENV["GITHUB_REF"] == "refs/heads/main"
      if is_production
        changelog += "🚀 Production Release\n"
        changelog += "• Stable release from main branch\n"
      else
        branch_name = ENV["GITHUB_REF_NAME"] || "development"
        changelog += "🧪 Development Build\n"
        changelog += "• Built from: #{branch_name}\n"
      end

      if ENV["GITHUB_SHA"]
        short_sha = ENV["GITHUB_SHA"][0..7]
        changelog += "• Commit: #{short_sha}\n"
      end
    end

    # Validate IPA file exists
    unless ipa_path && File.exist?(ipa_path)
      UI.error("❌ IPA file not found at: #{ipa_path}")
      raise "IPA file not found"
    end

    # Verify API key
    api_key = lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]
    if api_key.nil?
      app_store_connect_api_key(
        key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
        issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
        key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
        is_key_content_base64: true,
        in_house: false
      )
      api_key = lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]
    end

    # Prepare upload parameters
    upload_params = {
      api_key: api_key,
      app_identifier: ENV["BUNDLE_ID"],
      ipa: ipa_path,
      skip_waiting_for_build_processing: false,
      changelog: changelog,
      reject_build_waiting_for_review: true,
      uses_non_exempt_encryption: false,
      submit_beta_review: should_submit_for_review,
      wait_processing_timeout_duration: 1800
    }

    if test_groups.any?
      upload_params[:distribute_external] = true
      upload_params[:groups] = test_groups
      upload_params[:notify_external_testers] = true
    else
      upload_params[:distribute_external] = false
    end

    if ENV["BETA_CONTACT_EMAIL"] && ENV["BETA_CONTACT_PHONE"]
      upload_params[:beta_app_review_info] = {
        contact_email: ENV["BETA_CONTACT_EMAIL"],
        contact_first_name: "Support",
        contact_last_name: "Team",
        contact_phone: ENV["BETA_CONTACT_PHONE"],
        demo_account_name: ENV["BETA_DEMO_ACCOUNT_NAME"] || "",
        demo_account_password: ENV["BETA_DEMO_ACCOUNT_PASSWORD"] || "",
        notes: "This is a beta version for testing new features."
      }

      upload_params[:localized_app_info] = {
        "default" => {
          feedback_email: ENV["BETA_CONTACT_EMAIL"],
          description: "Flight price lock alerts and tracking"
        }
      }
    end

    begin
      upload_to_testflight(**upload_params)
    rescue => upload_error
      # If upload succeeded but distribution to external group failed (API key permission),
      # retry without external distribution — the build is already on TestFlight
      if upload_error.message.include?("forbidden") || upload_error.message.include?("does not allow")
        UI.important("⚠️ External distribution failed (API key permissions). Retrying without external distribution...")
        upload_params.delete(:distribute_external)
        upload_params.delete(:groups)
        upload_params.delete(:notify_external_testers)
        upload_params[:submit_beta_review] = false
        begin
          upload_to_testflight(**upload_params)
        rescue => retry_error
          # Build was already uploaded — if it fails again on processing check, that's OK
          if retry_error.message.include?("Another build is in review") || retry_error.message.include?("already exists")
            UI.important("⚠️ Build already exists on TestFlight — skipping: #{retry_error.message}")
          else
            UI.error("❌ Upload failed with error: #{retry_error.message}")
            raise retry_error
          end
        end
      else
        UI.error("❌ Upload failed with error: #{upload_error.message}")
        raise upload_error
      end
    end

    UI.success("✅ Successfully uploaded to TestFlight!")

    # ==========================================
    # STEP 7: CLEANUP AND RETURN DELIVERY INFO
    # ==========================================
    delete_keychain(
      name: keychain_name
    ) rescue nil

    {
      marketing_version: marketing_version,
      build_number: build_number,
      test_groups: test_groups,
      success: true
    }
  rescue => e
    UI.error("❌ Delivery failed: #{e.message}")

    if defined?(keychain_name)
      delete_keychain(
        name: keychain_name
      ) rescue nil
    end

    {
      success: false,
      error: e.message
    }
  end

  # ==========================================
  # ASSIGN BUILD TO GROUP LANE
  # ==========================================
  # Distributes an existing TestFlight build to a beta group without rebuilding.
  # If build_number is omitted, uses the latest available build for the current
  # marketing version read from Base.xcconfig.
  desc "Assign an existing TestFlight build to a beta group"
  lane :assign_build_to_group do |options|
    groups_input = options[:groups] || "Reviewers"
    groups = groups_input.split(",").map(&:strip).reject(&:empty?)
    UI.user_error!("At least one group is required") if groups.empty?

    app_version = options[:app_version]
    if app_version.nil? || app_version.to_s.empty?
      app_version = File.read("../#{ENV["APP_NAME"]}/App/Config/Base.xcconfig")
        .match(/^MARKETING_VERSION\s*=\s*(.+)$/)&.captures&.first&.strip
      UI.user_error!("Could not read MARKETING_VERSION from Base.xcconfig") if app_version.nil? || app_version.empty?
    end

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    build_number = options[:build_number]
    if build_number.nil? || build_number.to_s.empty?
      UI.message("🔎 Fetching latest TestFlight build for version #{app_version}...")
      build_number = latest_testflight_build_number(
        app_identifier: ENV["BUNDLE_ID"],
        version: app_version
      ).to_s
    end

    UI.message("🚀 Assigning build #{app_version} (#{build_number}) to groups: #{groups.join(', ')}")

    upload_to_testflight(
      app_identifier: ENV["BUNDLE_ID"],
      app_version: app_version,
      build_number: build_number,
      distribute_only: true,
      groups: groups,
      skip_waiting_for_build_processing: true,
      skip_submission: false
    )

    UI.success("✅ Build #{app_version} (#{build_number}) assigned to #{groups.join(', ')}")
  end

  # ==========================================
  # VALIDATE ONLY LANE
  # ==========================================
  desc "Validate build configuration without uploading"
  lane :validate_delivery do |options|
    scheme = options[:scheme] || ENV["APP_NAME"]

    UI.message("🔍 Validating build configuration")
    UI.message("📱 Scheme: #{scheme}")

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    gym(
      project: "#{ENV["APP_NAME"]}.xcodeproj",
      scheme: scheme,
      skip_build_archive: true,
      analyze_build_time: true
    )

    UI.success("✅ Build configuration is valid!")
  end
end

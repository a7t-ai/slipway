# ==========================================
# VERSION MANAGEMENT FASTFILE
# ==========================================
# This file contains all version-related lanes for the iOS app
# It handles version bumping with calendar-based logic and TestFlight integration
#
# Import this file in your main Fastfile with:
# import 'Fastfile.versioning.rb'

platform :ios do
  # ==========================================
  # MAIN VERSION BUMP LANE
  # ==========================================
  # This lane handles three types of version bumps:
  # 1. "new" - Creates a new marketing version based on current calendar date
  # 2. "current" - Keeps the current marketing version, only increments build number
  # 3. "next_week_release" - Creates a new marketing version based on date 7 days from now
  #
  # Version Format: YY.MM.BUILD (e.g., 25.08.3)
  # - YY: Last 2 digits of the year
  # - MM: Month with zero padding (01-12)
  # - BUILD: Incremental build number within that month
  #
  # Build Number: Always incrementing integer from TestFlight (e.g., 1234)
  desc "Bump version based on calendar or increment build number"
  lane :bump_version do |options|
    # ==========================================
    # STEP 1: READ CURRENT VERSION INFO
    # ==========================================
    # Read from Base.xcconfig file which stores our version numbers
    xcconfig_path = ENV["XCCONFIG_PATH"] || "#{ENV["APP_NAME"]}/Config/Base.xcconfig"

    # MARKETING_VERSION is the user-visible version (YY.MM.BUILD format)
    current_marketing_version = get_xcconfig_value(
      path: xcconfig_path,
      name: "MARKETING_VERSION"
    )

    # CURRENT_PROJECT_VERSION is the build number (always incrementing integer)
    current_build_number = get_xcconfig_value(
      path: xcconfig_path,
      name: "CURRENT_PROJECT_VERSION"
    ).to_i

    UI.message("📋 Current version info:")
    UI.message("  Marketing Version: #{current_marketing_version}")
    UI.message("  Build Number (config): #{current_build_number}")

    # ==========================================
    # STEP 1.5: CHECK FOR FORCED VERSIONS
    # ==========================================
    # Check if specific versions are being forced from the workflow
    forced_marketing_version = options[:force_marketing_version]
    forced_build_number = options[:force_build_number]

    if forced_marketing_version || forced_build_number
      UI.important("🎯 Force mode detected:")
      UI.message("📱 Forced marketing version: #{forced_marketing_version || 'Not set'}")
      UI.message("🔨 Forced build number: #{forced_build_number || 'Not set'}")
    end

    # ==========================================
    # STEP 2: PARSE CURRENT VERSION COMPONENTS
    # ==========================================
    # Split the marketing version into its components
    # Example: "25.07.3" becomes ["25", "07", "3"]
    version_parts = current_marketing_version.split(".")
    current_year = version_parts[0].to_i    # 25
    current_month = version_parts[1].to_i   # 7 (converted from "07")
    current_build = version_parts[2].to_i   # 3

    # ==========================================
    # STEP 3: GET TARGET DATE FOR COMPARISON
    # ==========================================
    # Determine which date to use based on version type
    is_next_week_release = options[:version_type] == "next_week_release"

    if is_next_week_release
      # For next_week_release, calculate date 7 days from now
      target_date = Time.now + (7 * 24 * 60 * 60)  # Add 7 days in seconds
      UI.message("📅 Target date (next week): #{target_date.strftime('%Y-%m-%d')}")
    else
      # For "new" and "current", use today's date
      target_date = Time.now
    end

    new_year = target_date.year % 100  # Convert 2025 to 25
    new_month = target_date.month      # Target month (1-12)

    # ==========================================
    # STEP 4: DETERMINE VERSION TYPE AND HANDLE FORCED VALUES
    # ==========================================
    if forced_marketing_version && forced_build_number
      # ==========================================
      # FORCED BOTH VALUES
      # ==========================================
      # Both marketing version and build number are forced
      new_marketing_version = forced_marketing_version
      new_build_number = forced_build_number.to_i

      UI.message("🎯 Using forced values: #{new_marketing_version} (#{new_build_number})")

    elsif forced_marketing_version
      # ==========================================
      # FORCED MARKETING VERSION ONLY
      # ==========================================
      # Marketing version is forced, but build number should be incremented
      new_marketing_version = forced_marketing_version
      testflight_build_number = get_latest_testflight_build_number
      UI.message("📦 TestFlight build number: #{testflight_build_number}")
      UI.message("ℹ️ Using TestFlight build number as source of truth for increment")
      new_build_number = testflight_build_number + 1

      UI.message("🎯 Using forced marketing version with incremented build: #{new_marketing_version} (#{new_build_number})")

    elsif forced_build_number
      # ==========================================
      # FORCED BUILD NUMBER ONLY
      # ==========================================
      # Build number is forced, marketing version follows normal logic
      new_build_number = forced_build_number.to_i

      # Determine marketing version based on version type
      is_new_version = options[:version_type] == "new"

      if is_new_version
        # Apply calendar-based logic for marketing version
        if new_year == current_year && new_month == current_month
          new_build = current_build + 1
          new_marketing_version = "#{current_year}.#{current_month.to_s.rjust(2, '0')}.#{new_build}"
        elsif new_year == current_year
          new_marketing_version = "#{new_year}.#{new_month.to_s.rjust(2, '0')}.1"
        else
          new_marketing_version = "#{new_year}.01.1"
        end
      else
        # Keep current marketing version
        new_marketing_version = current_marketing_version
      end

      UI.message("🎯 Using forced build number with #{is_new_version ? 'calendar-based' : 'current'} marketing version: #{new_marketing_version} (#{new_build_number})")

    else
      # ==========================================
      # NORMAL LOGIC (No forced values)
      # ==========================================
      # Check version type: "new", "next_week_release", or "current"
      # This is passed from the GitHub workflow
      is_new_version = options[:version_type] == "new"
      is_next_week_release = options[:version_type] == "next_week_release"

      if is_new_version || is_next_week_release
        # ==========================================
        # NEW VERSION LOGIC (Calendar-based)
        # ==========================================
        # Works for both "new" (today) and "next_week_release" (today + 7 days)
        # The target_date was already calculated in STEP 3

        if new_year == current_year && new_month == current_month
          # SCENARIO 1: Same year and month as current version
          # Example: Current is 25.08.2, target date is still August 2025
          # Result: 25.08.3 (increment the build number)
          new_build = current_build + 1
          new_marketing_version = "#{current_year}.#{current_month.to_s.rjust(2, '0')}.#{new_build}"

        elsif new_year == current_year
          # SCENARIO 2: Same year, but different month from current version
          # Example: Current is 25.08.4, target date is September 2025
          # Result: 25.09.1 (reset to .1 for new month)
          new_marketing_version = "#{new_year}.#{new_month.to_s.rjust(2, '0')}.1"

        else
          # SCENARIO 3: Different year from current version
          # Example: Current is 25.12.5, target date is January 2026
          # Result: 26.01.1 (new year starts at 01.1)
          new_marketing_version = "#{new_year}.01.1"
        end

        # For new versions, always increment the TestFlight build number
        testflight_build_number = get_latest_testflight_build_number
        UI.message("📦 TestFlight build number: #{testflight_build_number}")
        UI.message("ℹ️ Using TestFlight build number as source of truth for increment")
        new_build_number = testflight_build_number + 1

        version_type_desc = is_next_week_release ? "Next week's version" : "New version"
        UI.message("📱 #{version_type_desc}: #{new_marketing_version} (#{new_build_number})")
      else
        # ==========================================
        # CURRENT VERSION LOGIC (Build bump only)
        # ==========================================
        # This is typically used for hotfixes or when pushing to main
        # We keep the same marketing version but increment the build number
        # Example: 25.08.3 (1234) -> 25.08.3 (1235)
        new_marketing_version = current_marketing_version
        testflight_build_number = get_latest_testflight_build_number
        UI.message("📦 TestFlight build number: #{testflight_build_number}")
        UI.message("ℹ️ Using TestFlight build number as source of truth for increment")
        new_build_number = testflight_build_number + 1

        UI.message("🔨 Same version with new build: #{new_marketing_version} (#{new_build_number})")
      end
    end

    # ==========================================
    # STEP 5: UPDATE THE XCCONFIG FILE
    # ==========================================
    # Write the new version numbers back to Base.xcconfig
    update_xcconfig_value(
      path: xcconfig_path,
      name: "MARKETING_VERSION",
      value: new_marketing_version
    )
    update_xcconfig_value(
      path: xcconfig_path,
      name: "CURRENT_PROJECT_VERSION",
      value: new_build_number.to_s
    )

    # ==========================================
    # STEP 6: RETURN VERSION INFO
    # ==========================================
    # Return a hash with all version info for use in PR creation
    # This data will be used by the GitHub workflow
    {
      marketing_version: new_marketing_version,
      build_number: new_build_number,
      previous_marketing_version: current_marketing_version,
      previous_build_number: current_build_number
    }
  end

  # ==========================================
  # TESTFLIGHT BUILD NUMBER FETCHER
  # ==========================================
  # This private lane connects to App Store Connect API to get the latest
  # build number from TestFlight. This ensures we always increment from
  # the latest published build, avoiding conflicts.
  #
  # Required Environment Variables:
  # - APP_STORE_CONNECT_KEY_ID: Your API key identifier
  # - APP_STORE_CONNECT_ISSUER_ID: Your issuer ID from App Store Connect
  # - APP_STORE_CONNECT_KEY_CONTENT: The content of your .p8 private key file
  desc "Get latest TestFlight build number"
  private_lane :get_latest_testflight_build_number do
    # ==========================================
    # CONFIGURE APP STORE CONNECT API
    # ==========================================
    # Set up authentication using the API key
    # This avoids the need for username/password authentication
    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],  # Full .p8 file content
      is_key_content_base64: true,
      in_house: false  # Set to true only for Enterprise accounts
    )

    # ==========================================
    # FETCH LATEST BUILD NUMBER
    # ==========================================
    # Query TestFlight for the highest build number
    # If no builds exist, it returns initial_build_number (0)
    latest_build_number = latest_testflight_build_number(
      app_identifier: ENV["BUNDLE_ID"],
      initial_build_number: 0
    )

    UI.message("📦 Latest TestFlight build number: #{latest_build_number}")
    latest_build_number
  end
end

# ==========================================
# TESTING FASTFILE
# ==========================================
# This file contains all testing-related lanes for the iOS app
# It provides lanes for running unit tests, UI tests, and generating test reports
#
# Import this file in your main Fastfile with:
# import 'Fastfile.testing.rb'

platform :ios do
  # ==========================================
  # MAIN TEST LANE
  # ==========================================
  # This lane runs all unit tests for the iOS app
  # It supports multiple test plans and configurations
  #
  # Parameters:
  # - scheme: The Xcode scheme to use (default: ENV["APP_NAME"])
  # - ios_version: iOS simulator version (default: "26.0")
  # - device: Simulator device name (default: "iPhone 17")
  # - test_plan: Specific test plan to run (optional)
  # - clean: Whether to clean before building (default: true)
  #
  # Usage:
  #   fastlane test_suite
  #   fastlane test_suite ios_version:18.5 device:"iPhone 17"
  desc "Run unit tests with optional test plan"
  lane :test_suite do |options|
    # ==========================================
    # STEP 1: CONFIGURE TEST PARAMETERS
    # ==========================================
    # Set up test configuration with defaults
    scheme = options[:scheme] || ENV["APP_NAME"]
    ios_version = options[:ios_version] || "26.0"
    device = options[:device] || "iPhone 17"
    test_plan = options[:test_plan] || ENV["APP_NAME"]
    should_clean = options[:clean] != false  # Default to true

    UI.message("🧪 Running tests with configuration:")
    UI.message("  📱 Device: #{device}, iOS #{ios_version}")
    UI.message("  🎯 Scheme: #{scheme}")
    UI.message("  📋 Test Plan: #{test_plan}")

    # ==========================================
    # STEP 2: SETUP ENVIRONMENT
    # ==========================================
    # Configure Xcode environment for testing
    setup_test_environment

    # ==========================================
    # STEP 3: CLEAN BUILD FOLDER (OPTIONAL)
    # ==========================================
    if should_clean
      UI.message("🗑️ Cleaning build folder...")
      clear_derived_data
      cleanup_build_artifacts
    end

    # ==========================================
    # STEP 4: RESOLVE DEPENDENCIES
    # ==========================================
    # Ensure all Swift Package dependencies are resolved
    UI.message("📦 Resolving Swift package dependencies...")
    resolve_dependencies(
      project_path: "#{ENV["APP_NAME"]}.xcodeproj",
      scheme: scheme
    )

    # ==========================================
    # STEP 5: RUN TESTS
    # ==========================================
    # Execute the test suite with specified configuration
    begin
      test_results = run_test_suite(
        scheme: scheme,
        device: device,
        ios_version: ios_version,
        test_plan: test_plan
      )

      # ==========================================
      # STEP 6: PROCESS RESULTS
      # ==========================================
      # Parse and format test results
      process_test_results(test_results: test_results)

      UI.success("✅ All tests passed successfully!")
      test_results

    rescue => e
      UI.error("❌ Tests failed: #{e.message}")

      # Still try to process and report partial results
      # Extract failure details from xcresult bundle
      xcresult_path = "../TestResults/#{test_plan}.xcresult"
      if File.exist?(xcresult_path)
        extract_failure_details(xcresult_path: xcresult_path)
      end

      raise e
    end
  end

  # ==========================================
  # PRIVATE HELPER LANES
  # ==========================================

  desc "Setup test environment"
  private_lane :setup_test_environment do
    # ==========================================
    # CREATE TEST RESULTS DIRECTORY
    # ==========================================
    # Ensure clean test results directory using Ruby file operations
    test_results_dir = "../TestResults"
    if Dir.exist?(test_results_dir)
      FileUtils.rm_rf(test_results_dir)
      UI.message("🗑️ Cleaned existing TestResults directory")
    end
    FileUtils.mkdir_p(test_results_dir)
    UI.message("📁 Created TestResults directory")
  end

  desc "Resolve Swift package dependencies"
  private_lane :resolve_dependencies do |options|
    # Use xcodebuild to resolve packages
    xcodebuild(
      project: options[:project_path],
      scheme: options[:scheme],
      build_settings: {
        "COMPILER_INDEX_STORE_ENABLE" => "NO"
      },
      xcargs: "-resolvePackageDependencies"
    )
  end

  desc "Run the actual test suite"
  private_lane :run_test_suite do |options|
    # ==========================================
    # BUILD TEST COMMAND
    # ==========================================
    # Construct the scan parameters for testing

    # Combine device and iOS version for the device parameter
    device_name = options[:device] || "iPhone 17"
    ios_version = options[:ios_version] || "26.0"
    full_device = "#{device_name} (#{ios_version})"

    UI.message("📱 Using device: #{full_device}")

    scan_params = {
      project: "#{ENV["APP_NAME"]}.xcodeproj",
      scheme: options[:scheme],
      device: full_device,
      clean: false,  # We handle cleaning separately
      parallel_testing: false,  # Disable parallel testing to ensure report generation
      result_bundle: true,
      output_directory: "fastlane/test_output",
      output_types: "junit",
      output_files: "report.junit",
      disable_xcpretty: false,
      code_coverage: true,
      verbose: true,
      build_for_testing: false,
      skip_slack: true
    }

    # Use test plan if available
    test_plan_name = options[:test_plan] || ENV["APP_NAME"]
    test_plan_path = "../#{ENV["APP_NAME"]}/Resources/TestPlans/#{test_plan_name}.xctestplan"

    UI.message("🔍 Looking for test plan at: #{test_plan_path}")

    if File.exist?(test_plan_path)
      scan_params[:testplan] = test_plan_name
      UI.message("📋 Using test plan: #{test_plan_name}")
    else
      UI.message("⚠️ Test plan not found at: #{test_plan_path}, running without test plan")
    end

    # ==========================================
    # RUN TESTS WITH SCAN
    # ==========================================
    UI.message("🚀 Starting test execution...")

    begin
      scan_result = scan(scan_params)
      UI.success("✅ Scan completed successfully")
    rescue => e
      UI.error("❌ Scan failed with error: #{e.message}")
      raise e
    end

    # ==========================================
    # MOVE TEST RESULTS TO EXPECTED LOCATION
    # ==========================================
    UI.message("📁 Moving test results to TestResults directory...")

    project_root = File.expand_path("..")
    test_results_dir = File.join(project_root, "TestResults")
    FileUtils.mkdir_p(test_results_dir)

    # Look for xcresult bundles and copy them to TestResults
    xcresult_paths = [
      "./test_output/*.xcresult",
      "../fastlane/test_output/*.xcresult",
      File.join(project_root, "fastlane", "test_output", "*.xcresult")
    ]

    test_report_found = false

    xcresult_paths.each do |glob|
      xcresult_files = Dir.glob(glob)
      if xcresult_files.any?
        xcresult_files.each do |xcresult_path|
          next unless File.exist?(xcresult_path) && File.directory?(xcresult_path)

          timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
          basename = File.basename(xcresult_path, ".xcresult")
          target_filename = "#{basename}_#{timestamp}.xcresult"
          target_path = File.join(test_results_dir, target_filename)

          begin
            FileUtils.cp_r(xcresult_path, target_path)
            if File.exist?(target_path) && File.directory?(target_path)
              test_report_found = true
              UI.success("✅ Copied xcresult bundle: #{target_filename}")
            end
          rescue => e
            UI.error("❌ Failed to copy xcresult: #{e.message}")
          end
        end
        break if test_report_found
      end
    end

    # Move HTML report
    html_candidates = [
      "./test_output/report.html",
      File.join(project_root, "fastlane", "test_output", "report.html")
    ]
    html_target = File.join(test_results_dir, "report.html")

    html_candidates.each do |html_file|
      if File.exist?(html_file)
        FileUtils.cp(html_file, html_target)
        UI.success("✅ Copied HTML report to #{html_target}")
        break
      end
    end
  end

  desc "Process and format test results"
  private_lane :process_test_results do |options|
    results = options[:test_results]

    UI.message("📊 Test Results Summary:")
    if results && results.is_a?(Hash)
      UI.message("  ✅ Tests run: #{results[:tests_count] || 'N/A'}")
      UI.message("  ⏱️ Duration: #{results[:duration] || 'N/A'} seconds")
    else
      UI.message("  📋 Test execution completed (detailed metrics not available)")
      UI.message("  📄 Check TestResults directory for detailed reports")
    end

    # Generate coverage report
    xcresult_files = Dir.glob("../TestResults/*.xcresult")
    if xcresult_files.any?
      generate_coverage_report(xcresult_path: xcresult_files.first)
    end
  end

  desc "Generate code coverage report"
  private_lane :generate_coverage_report do |options|
    UI.message("📈 Generating code coverage report...")

    begin
      xcov(
        project: "#{ENV["APP_NAME"]}.xcodeproj",
        scheme: ENV["APP_NAME"],
        output_directory: "./TestResults/coverage",
        minimum_coverage_percentage: 0.0
      )
      UI.success("✅ Coverage report generated")
    rescue => e
      UI.important("⚠️ Could not generate coverage report: #{e.message}")
    end
  end

  desc "Extract failure details from test results"
  private_lane :extract_failure_details do |options|
    UI.message("🔍 Extracting failure details...")

    xcresult_path = options[:xcresult_path]
    if xcresult_path && File.exist?(xcresult_path)
      sh("xcrun xcresulttool get test-results summary --path #{xcresult_path}")
    else
      xcresult_files = Dir.glob("TestResults/*.xcresult")
      if xcresult_files.any?
        sh("xcrun xcresulttool get test-results summary --path #{xcresult_files.first}")
      end
    end
  end

  desc "Clean build artifacts"
  private_lane :cleanup_build_artifacts do
    UI.message("🧹 Cleaning build artifacts...")

    clear_derived_data

    build_paths = [
      "./build",
      "../build",
      "./DerivedData",
      "../DerivedData",
      "./fastlane/test_output"
    ]

    build_paths.each do |path|
      if Dir.exist?(path)
        FileUtils.rm_rf(path)
        UI.message("🗑️ Removed: #{path}")
      end
    end

    UI.success("✅ Build artifacts cleaned")
  end

  # ==========================================
  # CI/CD SPECIFIC LANE
  # ==========================================
  desc "Run tests optimized for CI"
  lane :ci_test do |options|
    ENV["FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT"] = "180"
    ENV["FASTLANE_XCODEBUILD_SETTINGS_RETRIES"] = "4"
    ENV["FASTLANE_SKIP_UPDATE_CHECK"] = "1"
    ENV["FASTLANE_HIDE_GITHUB_ISSUES_WARNING"] = "1"

    UI.message("🤖 Running tests in CI mode...")

    begin
      test_results = test_suite(
        scheme: options[:scheme] || ENV["APP_NAME"],
        ios_version: options[:ios_version] || "26.0",
        device: options[:device] || "iPhone 17",
        test_plan: options[:test_plan],
        clean: true
      )

      xcresult_bundles = Dir.glob("TestResults/*.xcresult")
      if xcresult_bundles.any?
        UI.message("📄 xcresult bundles available for dorny/test-reporter:")
        xcresult_bundles.each { |bundle| UI.message("  - #{File.basename(bundle)}") }
      end

      UI.success("✅ CI tests completed successfully")
      test_results

    rescue => e
      UI.error("❌ CI tests failed: #{e.message}")

      xcresult_files = Dir.glob("TestResults/*.xcresult")
      if xcresult_files.any?
        extract_failure_details(xcresult_path: xcresult_files.first)
      end
      raise e
    end
  end
end

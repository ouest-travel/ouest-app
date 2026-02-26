Run the full verification suite for the Ouest iOS app:

1. **Build check**: Run `xcodebuild -project Ouest.xcodeproj -scheme Ouest -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1` and verify it succeeds with zero errors
2. **Run tests**: Run `xcodebuild -project Ouest.xcodeproj -scheme Ouest -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1` and verify all tests pass
3. **Check for warnings**: Look for any compiler warnings in the build output (should be zero)
4. **Security review**: Check for these issues:
   - No hardcoded Supabase URL or anon key in any Swift file (should come from xcconfig via Info.plist)
   - No `service_role` key anywhere in the codebase
   - No API keys or tokens in committed files
   - All user inputs have validation before being sent to Supabase
   - Grep for common security issues: `grep -r "service_role\|hardcoded\|TODO.*secret\|password.*=" Ouest/ --include="*.swift"`
5. **RLS check**: Verify all Supabase migrations have RLS policies enabled
6. Report a summary of: build status, test results, warnings count, security findings

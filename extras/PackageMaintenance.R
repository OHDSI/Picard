# ============================================================================
# PICARD Package Maintenance Script
# ============================================================================
# 
# This script performs routine maintenance tasks for the picard package,
# including documenting code and updating the _pkgdown.yml reference structure.
#
# Usage: source("extras/PackageMaintenance.R")
#
# ============================================================================

cat("\n")
cat("================================================================================\n")
cat("PICARD Package Maintenance Script\n")
cat("================================================================================\n")

# Step 1: Document the package
cat("\n[1/7] Documenting package with roxygen2...\n")
devtools::document()
cat("✓ Documentation complete\n")

# Step 2: Reload the package to get fresh exports
cat("\n[2/7] Reloading package...\n")
devtools::load_all()
cat("✓ Package reloaded\n")

# Step 3: Source maintenance utilities
cat("\n[3/7] Loading maintenance utilities...\n")
source("extras/zzz_maintenance.R")
cat("✓ Utilities loaded\n")

# Step 4: Sync agent docs from vignettes
cat("\n[4/7] Syncing inst/agent docs from vignettes...\n")
sync_agent_docs_from_vignettes(dryRun = FALSE)
cat("✓ Agent docs synced\n")

# Step 5: Update pkgdown reference
cat("\n[5/7] Updating _pkgdown.yml reference section...\n")
update_pkgdown_reference()
cat("✓ pkgdown.yml updated\n")

# Step 6: Generate comprehensive report
cat("\n[6/7] Generating maintenance report...\n")
cat("\n")

validate_documentation(show_missing = TRUE)

cat("\n")

# Step 7: Build pkgdown site
cat("\n[7/7] Building pkgdown documentation site...\n")
pkgdown::build_site()
cat("✓ pkgdown site built\n")

cat("\n")
cat("================================================================================\n")
cat("NEXT STEPS:\n")
cat("================================================================================\n")
cat("\n")
cat("1. Review changes made to _pkgdown.yml in git:\n")
cat("   git diff _pkgdown.yml\n")
cat("\n")
cat("2. Preview the documentation site locally:\n")
cat("   - Open docs/index.html in your browser\n")
cat("   - Or run: pkgdown::preview()\n")
cat("\n")
cat("3. If satisfied with the changes, commit and push:\n")
cat("   git add .\n")
cat("   git commit -m 'Maintenance: Update documentation and pkgdown reference'\n")
cat("   git push origin main\n")
cat("\n")
cat("4. Deploy the updated site if using GitHub Pages!\n")
cat("\n")
cat("================================================================================\n")

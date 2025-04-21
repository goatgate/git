#!/bin/bash
# git-github-automation.sh
# A comprehensive script for automating Git and GitHub workflows
# Author: Claude
# Date: April 21, 2025

# Text colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
print_usage() {
    echo -e "${BLUE}Git & GitHub Automation Script${NC}"
    echo -e "Usage: $(basename "$0") [command] [options]"
    echo
    echo "Commands:"
    echo "  init [repo-name]              - Initialize a new Git repository locally and on GitHub"
    echo "  save [commit-message]         - Add all changes, commit, and push to remote"
    echo "  branch [branch-name]          - Create and switch to a new branch"
    echo "  pr [title] [description]      - Create a pull request (requires GitHub CLI)"
    echo "  sync                          - Sync current branch with remote main/master"
    echo "  clean                         - Remove untracked files and directories"
    echo "  log [n]                       - Show last n commits (default: 5)"
    echo "  status                        - Show repository status with enhanced output"
    echo "  release [version] [message]   - Create and push a new tag/release"
    echo "  clone [repo-url] [directory]  - Clone a repository with optimized settings"
    echo
    echo "Options:"
    echo "  -h, --help                    - Show this help message"
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: Git is not installed${NC}"
        echo "Please install Git first: https://git-scm.com/downloads"
        exit 1
    fi
}

# Check if GitHub CLI is installed (for PR creation)
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}Warning: GitHub CLI is not installed${NC}"
        echo "For PR creation, please install GitHub CLI: https://cli.github.com/"
        echo "Then authenticate with: gh auth login"
        return 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}Warning: Not authenticated with GitHub CLI${NC}"
        echo "Please run: gh auth login"
        return 1
    fi
    
    return 0
}

# Initialize a new repository
init_repo() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        repo_name=$(basename "$(pwd)")
        echo -e "${YELLOW}No repository name provided. Using current directory name: ${repo_name}${NC}"
    fi
    
    echo -e "${BLUE}Initializing repository: ${repo_name}${NC}"
    
    # Initialize local git repository
    git init
    
    # Create README.md if it doesn't exist
    if [ ! -f "README.md" ]; then
        echo "# ${repo_name}" > README.md
        echo -e "${GREEN}Created README.md${NC}"
    fi
    
    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << EOF
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.idea/
.vscode/
*.sublime-project
*.sublime-workspace

# Dependency directories
node_modules/
vendor/

# Log files
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Local env files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF
        echo -e "${GREEN}Created .gitignore with common patterns${NC}"
    fi
    
    # Make initial commit
    git add .
    git commit -m "Initial commit"
    
    # Create GitHub repository if GitHub CLI is available
    if check_gh_cli; then
        echo -e "${BLUE}Creating GitHub repository: ${repo_name}${NC}"
        gh repo create "$repo_name" --source=. --public --push
        echo -e "${GREEN}Repository created and pushed to GitHub: ${repo_name}${NC}"
    else
        echo -e "${YELLOW}GitHub CLI not available. Please create repository manually and then run:${NC}"
        echo "git remote add origin git@github.com:USERNAME/${repo_name}.git"
        echo "git branch -M main"
        echo "git push -u origin main"
    fi
}

# Save changes (add, commit, push)
save_changes() {
    local commit_message="$1"
    
    if [ -z "$commit_message" ]; then
        # Get current date and time for default commit message
        local datetime=$(date "+%Y-%m-%d %H:%M:%S")
        commit_message="Update - ${datetime}"
        echo -e "${YELLOW}No commit message provided. Using: ${commit_message}${NC}"
    fi
    
    echo -e "${BLUE}Saving changes...${NC}"
    
    # Check if there are any changes
    if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${YELLOW}No changes to commit${NC}"
        return 0
    fi
    
    # Add all changes
    git add .
    
    # Commit with message
    git commit -m "$commit_message"
    
    # Get current branch name
    local branch=$(git symbolic-ref --short HEAD)
    
    # Push to remote
    echo -e "${BLUE}Pushing to remote branch: ${branch}${NC}"
    if git push origin "$branch"; then
        echo -e "${GREEN}Successfully pushed changes to ${branch}${NC}"
    else
        echo -e "${YELLOW}Remote branch doesn't exist. Creating it now...${NC}"
        git push --set-upstream origin "$branch"
        echo -e "${GREEN}Successfully pushed changes to new branch: ${branch}${NC}"
    fi
}

# Create and switch to a new branch
create_branch() {
    local branch_name="$1"
    
    if [ -z "$branch_name" ]; then
        echo -e "${RED}Error: Branch name required${NC}"
        echo "Usage: $(basename "$0") branch [branch-name]"
        return 1
    fi
    
    echo -e "${BLUE}Creating branch: ${branch_name}${NC}"
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo -e "${YELLOW}Branch '$branch_name' already exists${NC}"
        echo -e "${BLUE}Switching to branch: ${branch_name}${NC}"
        git checkout "$branch_name"
    else
        # Create and switch to new branch
        git checkout -b "$branch_name"
        echo -e "${GREEN}Created and switched to new branch: ${branch_name}${NC}"
    fi
    
    # Push branch to remote if it doesn't exist there
    echo -e "${BLUE}Pushing branch to remote...${NC}"
    git push --set-upstream origin "$branch_name" && echo -e "${GREEN}Branch pushed to remote${NC}"
}

# Create a pull request
create_pr() {
    local title="$1"
    local description="$2"
    
    if ! check_gh_cli; then
        echo -e "${RED}Error: GitHub CLI required for PR creation${NC}"
        return 1
    fi
    
    if [ -z "$title" ]; then
        local branch=$(git symbolic-ref --short HEAD)
        title="Pull request for $branch"
        echo -e "${YELLOW}No PR title provided. Using: ${title}${NC}"
    fi
    
    if [ -z "$description" ]; then
        description="Changes made in $(git symbolic-ref --short HEAD)"
    fi
    
    echo -e "${BLUE}Creating pull request...${NC}"
    
    # Push current branch to make sure it's up-to-date
    git push
    
    # Create pull request
    gh pr create --title "$title" --body "$description"
    
    echo -e "${GREEN}Pull request created successfully${NC}"
}

# Sync with main/master
sync_branch() {
    echo -e "${BLUE}Syncing with main branch...${NC}"
    
    # Get current branch
    local current_branch=$(git symbolic-ref --short HEAD)
    
    # Determine default branch (main or master)
    local default_branch="main"
    if git show-ref --verify --quiet refs/remotes/origin/master; then
        default_branch="master"
    fi
    
    # Fetch latest from remote
    echo -e "${BLUE}Fetching latest changes...${NC}"
    git fetch origin
    
    # If not on default branch, do a rebase
    if [ "$current_branch" != "$default_branch" ]; then
        echo -e "${BLUE}Rebasing $current_branch onto origin/${default_branch}...${NC}"
        if git rebase "origin/${default_branch}"; then
            echo -e "${GREEN}Successfully rebased onto ${default_branch}${NC}"
        else
            echo -e "${RED}Rebase conflict! Aborting rebase...${NC}"
            git rebase --abort
            echo -e "${YELLOW}Please merge manually:${NC}"
            echo "git checkout ${default_branch}"
            echo "git pull"
            echo "git checkout ${current_branch}"
            echo "git merge ${default_branch}"
            return 1
        fi
    else
        # On default branch, do a pull
        echo -e "${BLUE}Pulling latest changes for ${default_branch}...${NC}"
        git pull origin "$default_branch"
    fi
    
    echo -e "${GREEN}Branch is now in sync with ${default_branch}${NC}"
}

# Clean repository
clean_repo() {
    echo -e "${YELLOW}WARNING: This will remove all untracked files and directories.${NC}"
    echo -e "${YELLOW}These changes cannot be recovered.${NC}"
    read -p "Are you sure you want to continue? (y/n): " confirm
    
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo -e "${BLUE}Cleaning repository...${NC}"
        
        # Show what will be removed
        echo -e "${BLUE}Files and directories that will be removed:${NC}"
        git clean -fd --dry-run
        
        # Confirm again
        read -p "Proceed with removal? (y/n): " confirm2
        
        if [[ $confirm2 == [yY] || $confirm2 == [yY][eE][sS] ]]; then
            # Remove untracked files and directories
            git clean -fd
            echo -e "${GREEN}Repository cleaned successfully${NC}"
        else
            echo -e "${YELLOW}Clean operation cancelled${NC}"
        fi
    else
        echo -e "${YELLOW}Clean operation cancelled${NC}"
    fi
}

# Show git log
show_log() {
    local num="$1"
    
    if [ -z "$num" ]; then
        num=5
    fi
    
    echo -e "${BLUE}Showing last $num commits:${NC}"
    git log --oneline --graph --decorate --all -n "$num"
}

# Show enhanced status
show_status() {
    echo -e "${BLUE}Repository Status:${NC}"
    echo "=============================="
    
    # Get current branch
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "(detached HEAD)")
    echo -e "${BLUE}Current branch:${NC} $branch"
    
    # Get remote status
    local remote_branch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
    
    if [ -n "$remote_branch" ]; then
        echo -e "${BLUE}Remote branch:${NC} $remote_branch"
        
        # Get ahead/behind counts
        local ahead_behind=$(git rev-list --left-right --count "$branch...$remote_branch" 2>/dev/null)
        local ahead=$(echo "$ahead_behind" | awk '{print $1}')
        local behind=$(echo "$ahead_behind" | awk '{print $2}')
        
        if [ "$ahead" -gt 0 ]; then
            echo -e "${YELLOW}Local is ahead by $ahead commit(s)${NC}"
        fi
        
        if [ "$behind" -gt 0 ]; then
            echo -e "${YELLOW}Local is behind by $behind commit(s)${NC}"
        fi
        
        if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
            echo -e "${GREEN}Local is in sync with remote${NC}"
        fi
    else
        echo -e "${YELLOW}No remote tracking branch set${NC}"
    fi
    
    echo -e "\n${BLUE}Local Changes:${NC}"
    git status -s
    
    # Show stash count
    local stash_count=$(git stash list | wc -l | tr -d ' ')
    if [ "$stash_count" -gt 0 ]; then
        echo -e "\n${YELLOW}Stashed changes: $stash_count${NC}"
    fi
}

# Create a release
create_release() {
    local version="$1"
    local message="$2"
    
    if [ -z "$version" ]; then
        echo -e "${RED}Error: Version required${NC}"
        echo "Usage: $(basename "$0") release [version] [message]"
        return 1
    fi
    
    # Ensure version starts with v if not already
    if [[ ! "$version" =~ ^v ]]; then
        version="v$version"
    fi
    
    if [ -z "$message" ]; then
        message="Release $version"
    fi
    
    echo -e "${BLUE}Creating release: ${version}${NC}"
    
    # Create tag
    git tag -a "$version" -m "$message"
    
    # Push tag
    git push origin "$version"
    
    # Create GitHub release if GitHub CLI is available
    if check_gh_cli; then
        echo -e "${BLUE}Creating GitHub release...${NC}"
        gh release create "$version" --title "$version" --notes "$message"
        echo -e "${GREEN}GitHub release created: ${version}${NC}"
    else
        echo -e "${GREEN}Tag pushed. Create release on GitHub manually if needed.${NC}"
    fi
}

# Clone repository with optimized settings
clone_repo() {
    local repo_url="$1"
    local directory="$2"
    
    if [ -z "$repo_url" ]; then
        echo -e "${RED}Error: Repository URL required${NC}"
        echo "Usage: $(basename "$0") clone [repo-url] [directory]"
        return 1
    fi
    
    echo -e "${BLUE}Cloning repository: ${repo_url}${NC}"
    
    # Clone with depth 1 if no directory specified
    if [ -z "$directory" ]; then
        git clone --depth 1 "$repo_url"
    else
        git clone --depth 1 "$repo_url" "$directory"
    fi
    
    # Get the directory name
    if [ -z "$directory" ]; then
        directory=$(basename "$repo_url" .git)
    fi
    
    # Enter directory
    cd "$directory" || return 1
    
    # Fetch all branches
    echo -e "${BLUE}Fetching all branches...${NC}"
    git fetch --all
    
    # Set useful git configs
    git config pull.rebase true
    git config fetch.prune true
    
    echo -e "${GREEN}Repository cloned successfully to: ${directory}${NC}"
    echo -e "${BLUE}Current branches:${NC}"
    git branch -a
}

# Main function to handle commands
main() {
    # Check if git is installed
    check_git
    
    # No arguments provided
    if [ $# -eq 0 ]; then
        print_usage
        exit 0
    fi
    
    # Parse command
    command="$1"
    shift
    
    case "$command" in
        init)
            init_repo "$1"
            ;;
        save)
            save_changes "$*"
            ;;
        branch)
            create_branch "$1"
            ;;
        pr)
            create_pr "$1" "$2"
            ;;
        sync)
            sync_branch
            ;;
        clean)
            clean_repo
            ;;
        log)
            show_log "$1"
            ;;
        status)
            show_status
            ;;
        release)
            create_release "$1" "$2"
            ;;
        clone)
            clone_repo "$1" "$2"
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo -e "${RED}Unknown command: ${command}${NC}"
            print_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
terramate {
  config {
    git {
      default_remote = "origin"
      default_branch = "main"
    }
  }
}

scaffold {
  package_sources = [
    "github.com/ImIOImI/catalyst-v017-regression",
  ]
}

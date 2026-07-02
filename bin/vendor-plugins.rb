#!/usr/bin/env ruby
# Vendors external plugin repos into this marketplace repo and regenerates the
# plugins array in .claude-plugin/marketplace.json from the vendored repos'
# own manifests.
#
# Config lives in vendor-plugins.json at the repo root:
#   [
#     { "repo": "owner/name", "path": "local-dir" },
#     { "repo": "owner/name", "path": "other-dir", "ref": "v1.2.0",
#       "overrides": { "relevance": { "...": "replaces that key on each entry" } } }
#   ]
#
# For each entry the repo is cloned and rsynced into <path>/. Plugin entries
# come from <path>/.claude-plugin/marketplace.json (sources rewritten to
# ./<path>/...), or are synthesized from <path>/.claude-plugin/plugin.json for
# single-plugin repos. Manifest entries pointing into a vendored path are
# replaced; hand-written entries elsewhere are preserved.

require "json"
require "fileutils"
require "tmpdir"

MANIFEST = ".claude-plugin/marketplace.json"
CONFIG = "vendor-plugins.json"

def sh!(*cmd)
  system(*cmd) or abort("command failed: #{cmd.join(" ")}")
end

def plugin_entries(path)
  marketplace = File.join(path, ".claude-plugin", "marketplace.json")
  plugin = File.join(path, ".claude-plugin", "plugin.json")

  if File.exist?(marketplace)
    JSON.parse(File.read(marketplace)).fetch("plugins", []).map do |entry|
      if entry["source"].is_a?(String)
        rel = entry["source"].sub(%r{\A\./?}, "")
        entry["source"] = rel.empty? ? "./#{path}" : "./#{path}/#{rel}"
      end
      entry
    end
  elsif File.exist?(plugin)
    meta = JSON.parse(File.read(plugin))
    [{ "name" => meta["name"], "source" => "./#{path}", "description" => meta["description"] }.compact]
  else
    warn "warning: #{path} has no .claude-plugin/{marketplace,plugin}.json — vendored files only"
    []
  end
end

generated = []
vendored_paths = []

JSON.parse(File.read(CONFIG)).each do |cfg|
  repo, path, ref = cfg.values_at("repo", "path", "ref")
  if path.to_s.empty? || path.start_with?("/") || path.split("/").any? { |seg| seg == "." || seg == ".." }
    abort("unsafe path: #{path.inspect}")
  end

  Dir.mktmpdir do |tmp|
    sh!("git", "clone", "--depth", "1", *(ref ? ["--branch", ref] : []), "https://github.com/#{repo}.git", tmp)
    upstream = IO.popen(["git", "-C", tmp, "rev-parse", "HEAD"], &:read).strip
    FileUtils.mkdir_p(path)
    sh!("rsync", "-a", "--delete", "--exclude", ".git", "#{tmp}/", "#{path}/")
    File.write(File.join(path, ".vendored-from"), "#{repo}@#{upstream}\n")

    entries = plugin_entries(path).map { |e| e.merge(cfg.fetch("overrides", {})) }
    generated.concat(entries)
    vendored_paths << path
    puts "Vendored #{repo}@#{upstream} -> #{path}/ (#{entries.size} plugin entries)"
  end
end

manifest = JSON.parse(File.read(MANIFEST))
manifest["plugins"] = manifest.fetch("plugins", []).reject { |p|
  p["source"].is_a?(String) &&
    vendored_paths.any? { |v| p["source"] == "./#{v}" || p["source"].start_with?("./#{v}/") }
} + generated
File.write(MANIFEST, JSON.pretty_generate(manifest) + "\n")
puts "Regenerated #{MANIFEST} with #{manifest["plugins"].size} plugin(s)."

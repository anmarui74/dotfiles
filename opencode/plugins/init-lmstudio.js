export const InitLMStudio = async ({ $ }) => {
  await $`bash /home/antonio/.config/opencode/init-opencode.sh`.quiet()
}

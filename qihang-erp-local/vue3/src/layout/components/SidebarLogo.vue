<template>
  <div class="sidebar-logo-container" :class="{ collapse }">
    <router-link class="sidebar-logo-link" to="/">
      <h1 class="sidebar-title">{{ collapse ? 'E' : title }}</h1>
      <span v-if="!collapse" class="sidebar-signature">Ethan · 个人工作台</span>
    </router-link>
  </div>
</template>

<script setup lang="ts">
interface Props {
  collapse: boolean
}

withDefaults(defineProps<Props>(), { collapse: false })

const title = import.meta.env.VITE_APP_TITLE
</script>

<style lang="scss" scoped>
.sidebar-logo-container {
  position: relative;
  width: 100%;
  height: 50px;
  line-height: 50px;
  background: #ffffff;
  text-align: center;
  overflow: hidden;

  .sidebar-logo-link {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    height: 100%;
    width: 100%;
    text-decoration: none;

    .sidebar-title {
      display: inline-block;
      margin: 0;
      color: #001529;
      font-weight: 600;
      line-height: 23px;
      font-size: 16px;
      font-family: Avenir, Helvetica Neue, Arial, Helvetica, sans-serif;
      vertical-align: middle;
    }
    .sidebar-signature { font-size: 10px; line-height: 15px; color: #606266; }
  }
}
</style>

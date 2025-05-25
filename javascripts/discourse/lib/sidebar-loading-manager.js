// Manages the loading state and prevents flicker for custom sidebar sections
export class SidebarLoadingManager {
  static getInstance() {
    if (!window.sidebarLoadingManager) {
      window.sidebarLoadingManager = new SidebarLoadingManager();
    }
    return window.sidebarLoadingManager;
  }

constructor() {
    this.loadingStates = new Map();
    this.pendingUpdates = new Set();
    this.initialized = false;
  }



  markSectionAsLoading(sectionName) {
    this.loadingStates.set(sectionName, 'loading');
    this.addLoadingClass(sectionName);
  }

  markSectionAsLoaded(sectionName) {
    this.loadingStates.set(sectionName, 'loaded');
    this.removeLoadingClass(sectionName);
    this.addLoadedClass(sectionName);
  }

  addLoadingClass(sectionName) {
    const sections = document.querySelectorAll(
      `.custom-sidebar-section[data-sidebar-name="${sectionName}"]`
    );
    for (const section of sections) {
      section.classList.add('loading');
      section.classList.remove('loaded');
    }
  }

  removeLoadingClass(sectionName) {
    const sections = document.querySelectorAll(
      `.custom-sidebar-section[data-sidebar-name="${sectionName}"]`
    );
    for (const section of sections) {
      section.classList.remove('loading');
    }
  }

  addLoadedClass(sectionName) {
    const sections = document.querySelectorAll(
      `.custom-sidebar-section[data-sidebar-name="${sectionName}"]`
    );
    for (const section of sections) {
      section.classList.add('loaded');
    }
  }

  isLoaded(sectionName) {
    return this.loadingStates.get(sectionName) === 'loaded';
  }

  isLoading(sectionName) {
    return this.loadingStates.get(sectionName) === 'loading';
  }

  reset() {
    this.loadingStates.clear();
    this.pendingUpdates.clear();
    // Remove all loading/loaded classes
    const sections = document.querySelectorAll('.custom-sidebar-section');
    for (const section of sections) {
      section.classList.remove('loading', 'loaded');
    }
  }

  scheduleUpdate(callback, delay = 50) {
    const updateId = Date.now() + Math.random();
    this.pendingUpdates.add(updateId);

    setTimeout(() => {
      if (this.pendingUpdates.has(updateId)) {
        this.pendingUpdates.delete(updateId);
        callback();
      }
    }, delay);

    return updateId;
  }

  cancelUpdate(updateId) {
    this.pendingUpdates.delete(updateId);
  }
}

export default SidebarLoadingManager;

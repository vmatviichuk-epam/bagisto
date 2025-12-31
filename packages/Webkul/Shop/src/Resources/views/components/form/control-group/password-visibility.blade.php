<v-password-visibility {{ $attributes }}>
    {{ $slot }}
</v-password-visibility>

@pushOnce('scripts')
    <script
        type="text/x-template"
        id="v-password-visibility-template"
    >
        <div class="relative">
            <slot></slot>

            <button
                type="button"
                class="absolute top-1/2 -translate-y-1/2 flex items-center justify-center text-2xl text-gray-600 transition-colors hover:text-gray-800"
                :style="isRtl ? 'left: 1rem' : 'right: 1rem'"
                :aria-label="isPasswordVisible ? '@lang('shop::app.components.form.password-visibility.hide-password')' : '@lang('shop::app.components.form.password-visibility.show-password')'"
                @click="toggleVisibility"
            >
                <span
                    class="transition-all"
                    :class="isPasswordVisible ? 'icon-eye-hide' : 'icon-eye'"
                ></span>
            </button>
        </div>
    </script>

    <script type="module">
        app.component('v-password-visibility', {
            template: '#v-password-visibility-template',

            data() {
                return {
                    isPasswordVisible: false,
                };
            },

            computed: {
                isRtl() {
                    return document.documentElement.dir === 'rtl';
                },
            },

            mounted() {
                this.inputElement = this.$el.querySelector('input');
            },

            methods: {
                toggleVisibility() {
                    this.isPasswordVisible = !this.isPasswordVisible;

                    if (this.inputElement) {
                        this.inputElement.type = this.isPasswordVisible ? 'text' : 'password';
                    }
                },
            },
        });
    </script>
@endPushOnce

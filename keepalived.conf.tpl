global_defs {

    router_id  ssj-VIP
}

vrrp_instance VI_1 {

   state  SLAVE

   nopreempt 

   interface NET_IF

   virtual_router_id ID

   priority  PRIORITY

   advert_int 3

   authentication {

        auth_type PASS

        auth_pass 5566   

   }

   virtual_ipaddress {

        VIP/24 dev NET_IF  scope global label NET_IF:1

        }

   }


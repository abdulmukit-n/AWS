# AWS
aws related documentation, knowledge docs, scripts


---
Multi_sg_rules.sh

this will add a portocol:all , port:all for an IP in a region to all the Security groups. (values need to be modified for IP and region in the file before it is ran)

it will be ran from within the CLI , in the file it does tracking for cloudshell user but that path can be changed. tracking files are good for checking SGs that change was made to and not made to succesfully.

tracking effectively can only be done with a special tag value that you also have to fill on line 11 (in order to perform a delete on this multi rule in the future)

---
Delete_multi_sg_rules.sh

is complementary to multi_sg_rules.sg , as it checks for the rules with the tag and specific IP in region for SGs that match created from the creation script and deletes only those created.

you need to add IP , region , tag value (this is when calling the script in CLI add the tag value as a input right next to calling the script: ./delete_multi_sg_rules.sh *tag_value*)

---
